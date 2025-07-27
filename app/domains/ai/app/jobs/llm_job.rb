# frozen_string_literal: true

require Rails.root.join('lib', 'api_client_factory') if defined?(Rails)

class LLMJob < ApplicationJob
  queue_as :default

  # Configure Sidekiq retry with exponential backoff
  sidekiq_options retry: 5, backtrace: true

  # Exponential backoff with jitter
  sidekiq_retry_in do |count, exception|
    base_delay = 5 # seconds
    max_delay = 300 # 5 minutes max
    jitter = rand(0.5..1.5)
    
    delay = [base_delay * (2 ** count) * jitter, max_delay].min
    Rails.logger.info "LLMJob retry #{count + 1}/5 in #{delay.round(2)} seconds: #{exception.class}: #{exception.message}"
    delay
  end

  def perform(template:, model:, context: {}, format: 'text', user_id: nil, agent_id: nil, mcp_fetchers: [], workspace_id: nil)
    Rails.logger.info "Starting LLMJob", {
      template: template,
      model: model,
      context_keys: context.keys,
      format: format,
      user_id: user_id,
      agent_id: agent_id,
      mcp_fetchers: mcp_fetchers,
      workspace_id: workspace_id,
      job_id: job_id
    }

    workspace = workspace_id ? Workspace.find_by(id: workspace_id) : nil
    
    # Check rate limits before processing
    if workspace&.workspace_spending_limit&.rate_limit_enabled?
      spending_limit = workspace.workspace_spending_limit
      
      if spending_limit.would_be_rate_limited?
        if spending_limit.block_when_rate_limited?
          raise StandardError.new("Rate limit exceeded for workspace #{workspace_id}")
        else
          Rails.logger.warn "Rate limit exceeded but not blocking", {
            workspace_id: workspace_id,
            job_id: job_id
          }
        end
      end
      
      # Record the request attempt
      spending_limit.add_request!
    end

    routing_policy = workspace&.ai_routing_policies&.enabled&.first

    # Build MCP context with base data
    enriched_context = build_mcp_context(context, mcp_fetchers, user_id)

    # Get the prompt template
    prompt_template = find_prompt_template(template)
    
    # Interpolate context variables into the template
    prompt = interpolate_template(prompt_template, enriched_context)
    
    # Estimate token usage and cost
    input_tokens = estimate_tokens(prompt)
    max_output_tokens = determine_max_tokens(format)
    
    # Execute with routing policy if available
    if routing_policy
      response, routing_decision = execute_with_routing_policy(
        routing_policy, prompt, format, input_tokens, max_output_tokens
      )
    else
      # Fallback to direct execution
      response = call_llm_api(model, prompt, format)
      routing_decision = { 
        policy_used: false, 
        primary_model: model, 
        final_model: model,
        total_attempts: 1 
      }
    end
    
    # Store the output
    llm_output = store_output(
      template: template,
      model: model,
      context: enriched_context,
      format: format,
      prompt: prompt,
      raw_response: response[:raw],
      parsed_output: response[:parsed],
      user_id: user_id,
      agent_id: agent_id,
      workspace_id: workspace_id,
      routing_decision: routing_decision,
      estimated_cost: response[:estimated_cost],
      input_tokens: input_tokens,
      output_tokens: response[:output_tokens],
      cost_warning_triggered: response[:cost_warning_triggered]
    )

    # Update actual cost if available from API response
    if response[:actual_cost]
      llm_output.update_actual_cost!(
        response[:actual_cost],
        input_tokens: response[:input_tokens],
        output_tokens: response[:output_tokens]
      )
    end

    Rails.logger.info "LLMJob completed successfully", {
      job_id: job_id,
      output_id: llm_output.id,
      response_length: response[:raw]&.length || 0,
      routing_used: routing_policy.present?,
      final_model: routing_decision[:final_model],
      estimated_cost: response[:estimated_cost],
      cost_warning: response[:cost_warning_triggered]
    }

    llm_output
  rescue => e
    Rails.logger.error "LLMJob failed", {
      job_id: job_id,
      error: e.class.name,
      message: e.message,
      backtrace: e.backtrace.first(5)
    }
    raise
  end

  private

  # Build enriched context using MCP fetchers
  def build_mcp_context(base_context, mcp_fetchers, user_id)
    # Create MCP context with base data
    user = user_id ? User.find_by(id: user_id) : nil
    mcp_context = Mcp::Context.new(**base_context.merge(user: user))

    # Process MCP fetchers if provided
    if mcp_fetchers.present?
      mcp_fetchers.each do |fetcher_config|
        fetcher_key = fetcher_config[:key]&.to_sym
        fetcher_params = fetcher_config[:params] || {}
        
        next unless fetcher_key

        begin
          Rails.logger.info("MCP: Fetching data for '#{fetcher_key}' with params: #{fetcher_params}")
          mcp_context.fetch(fetcher_key, **fetcher_params)
        rescue => e
          Rails.logger.error("MCP: Failed to fetch '#{fetcher_key}': #{e.message}")
          # Continue with other fetchers even if one fails
        end
      end
    end

    # Return enriched context
    enriched_context = mcp_context.to_h
    
    Rails.logger.info "LLMJob context enrichment", {
      original_keys: base_context.keys,
      enriched_keys: enriched_context.keys,
      mcp_errors: mcp_context.error_keys
    }

    enriched_context
  rescue => e
    Rails.logger.error("MCP context building failed: #{e.message}")
    # Fallback to original context if MCP fails
    base_context
  end

  def find_prompt_template(template)
    # In a real implementation, this would fetch from a PromptTemplate model
    # For now, return the template as-is
    template
  end

  def interpolate_template(template, context)
    # Simple variable interpolation - replace {{variable}} with context values
    result = template.dup
    context.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end

  def call_llm_api(model, prompt, format)
    # Use API client factory to get appropriate client based on environment
    client = ApiClientFactory.openai_client
    
    begin
      # Prepare messages for chat completion
      messages = [
        { role: 'user', content: prompt }
      ]
      
      # Call the API
      response = client.completions(
        model: model,
        messages: messages,
        max_tokens: determine_max_tokens(format),
        temperature: 0.7
      )
      
      # Extract response content
      raw_response = response.dig('choices', 0, 'message', 'content') || ''
      
      # Parse response based on format
      parsed_response = case format
                       when 'json'
                         begin
                           JSON.parse(raw_response)
                         rescue JSON::ParserError
                           { "response" => raw_response, "format_error" => "Invalid JSON response" }
                         end
                       else
                         raw_response
                       end
      
      {
        raw: raw_response,
        parsed: parsed_response
      }
    rescue => e
      Rails.logger.error("LLM API call failed: #{e.message}")
      
      # Fallback response
      fallback_response = generate_fallback_response(prompt, format)
      {
        raw: fallback_response,
        parsed: fallback_response,
        error: e.message
      }
    end
  end

  def store_output(template:, model:, context:, format:, prompt:, raw_response:, parsed_output:, user_id:, agent_id:, workspace_id: nil, routing_decision: {}, estimated_cost: nil, input_tokens: nil, output_tokens: nil, cost_warning_triggered: false)
    LLMOutput.create!(
      template_name: template,
      model_name: model,
      context: context,
      format: format,
      prompt: prompt,
      raw_response: raw_response,
      parsed_output: parsed_output,
      user_id: user_id,
      agent_id: agent_id,
      workspace_id: workspace_id,
      job_id: job_id,
      status: 'completed',
      routing_decision: routing_decision,
      estimated_cost: estimated_cost,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost_warning_triggered: cost_warning_triggered
    )
  end

  def determine_max_tokens(format)
    case format
    when 'json'
      500
    when 'markdown'
      1000
    else
      200
    end
  end

  def generate_fallback_response(prompt, format)
    case format
    when 'json'
      { "response" => "Fallback response for: #{prompt[0..50]}...", "error" => "API unavailable" }.to_json
    when 'markdown'
      "# Fallback Response\n\nAPI temporarily unavailable for prompt: #{prompt[0..50]}..."
    else
      "Fallback response for: #{prompt[0..50]}..."
    end
  end

  # Execute request with routing policy
  def execute_with_routing_policy(policy, prompt, format, input_tokens, max_output_tokens)
    routing_decision = {
      policy_used: true,
      policy_name: policy.name,
      primary_model: policy.primary_model,
      total_attempts: 0,
      attempts: [],
      final_model: nil,
      cost_checks: []
    }

    cost_warning_triggered = false
    last_error = nil
    
    # Try each model in the routing policy
    policy.ordered_models.each_with_index do |model, index|
      attempt_number = index + 1
      routing_decision[:total_attempts] = attempt_number

      begin
        # Estimate cost for this model
        estimated_cost = policy.estimate_cost(input_tokens, max_output_tokens, model)
        cost_check = policy.cost_check(estimated_cost)
        
        routing_decision[:cost_checks] << {
          model: model,
          estimated_cost: estimated_cost,
          check_result: cost_check
        }

        Rails.logger.info "LLM routing attempt", {
          attempt: attempt_number,
          model: model,
          estimated_cost: estimated_cost,
          cost_check: cost_check[:action]
        }

        # Check workspace spending limits if applicable
        if policy.workspace.workspace_spending_limit&.enabled?
          spending_limit = policy.workspace.workspace_spending_limit
          if spending_limit.would_exceed?(estimated_cost)
            if spending_limit.block_when_exceeded?
              raise StandardError.new("Workspace spending limit would be exceeded")
            else
              cost_warning_triggered = true
              Rails.logger.warn "Workspace spending limit warning", {
                workspace_id: policy.workspace.id,
                estimated_cost: estimated_cost,
                remaining_budget: spending_limit.remaining_budget
              }
            end
          end
        end

        # Handle cost-based decisions
        case cost_check[:action]
        when :block
          raise StandardError.new("Cost threshold exceeded: #{cost_check[:reason]}")
        when :warn
          cost_warning_triggered = true
          Rails.logger.warn "Cost warning triggered", {
            model: model,
            reason: cost_check[:reason]
          }
        end

        # Make the API call
        response = call_llm_api(model, prompt, format)
        
        # Success - record attempt and return
        routing_decision[:attempts] << {
          model: model,
          success: true,
          estimated_cost: estimated_cost,
          response_length: response[:raw]&.length || 0
        }
        routing_decision[:final_model] = model
        
        return [
          response.merge(
            estimated_cost: estimated_cost,
            cost_warning_triggered: cost_warning_triggered
          ),
          routing_decision
        ]

      rescue => error
        last_error = error
        
        routing_decision[:attempts] << {
          model: model,
          success: false,
          error: error.class.name,
          error_message: error.message,
          estimated_cost: estimated_cost
        }

        Rails.logger.warn "LLM routing attempt failed", {
          attempt: attempt_number,
          model: model,
          error: error.class.name,
          message: error.message
        }

        # Check if we should retry with next model
        unless policy.should_retry?(error, attempt_number)
          Rails.logger.error "LLM routing stopping retries", {
            attempt: attempt_number,
            error: error.class.name,
            message: error.message
          }
          break
        end

        # Add delay before retry if configured
        sleep(policy.effective_routing_rules['retry_delay']) if policy.effective_routing_rules['retry_delay'] > 0
      end
    end

    # All attempts failed - return fallback response
    Rails.logger.error "All LLM routing attempts failed", {
      total_attempts: routing_decision[:total_attempts],
      last_error: last_error&.message
    }

    fallback_response = generate_fallback_response(prompt, format)
    response = {
      raw: fallback_response,
      parsed: fallback_response,
      error: last_error&.message || "All models failed",
      estimated_cost: 0.0,
      cost_warning_triggered: cost_warning_triggered
    }

    routing_decision[:final_model] = 'fallback'
    
    [response, routing_decision]
  end

  # Estimate token count for input text
  def estimate_tokens(text)
    # Simple estimation: ~4 characters per token for English text
    (text&.length || 0) / 4
  end
end