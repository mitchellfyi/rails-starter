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

  def perform(template:, model:, context: {}, format: 'text', user_id: nil, agent_id: nil, mcp_fetchers: [])
    Rails.logger.info "Starting LLMJob", {
      template: template,
      model: model,
      context_keys: context.keys,
      format: format,
      user_id: user_id,
      agent_id: agent_id,
      mcp_fetchers: mcp_fetchers,
      job_id: job_id
    }

    # Build MCP context with base data
    enriched_context = build_mcp_context(context, mcp_fetchers, user_id)

    # Get the prompt template
    prompt_template = find_prompt_template(template)
    
    # Interpolate context variables into the template
    prompt = interpolate_template(prompt_template, enriched_context)
    
    # Call the LLM API
    response = call_llm_api(model, prompt, format)
    
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
      agent_id: agent_id
    )

    Rails.logger.info "LLMJob completed successfully", {
      job_id: job_id,
      output_id: llm_output.id,
      response_length: response[:raw]&.length || 0
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

  def store_output(template:, model:, context:, format:, prompt:, raw_response:, parsed_output:, user_id:, agent_id:)
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
      job_id: job_id,
      status: 'completed'
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
end