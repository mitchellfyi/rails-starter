# frozen_string_literal: true

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

  # Class method to create workspace-scoped job runner
  def self.for(workspace)
    WorkspaceLLMJobRunner.new(workspace)
  end

  def perform(template:, model:, context: {}, format: 'text', user_id: nil, agent_id: nil, ai_credential_id: nil, workspace_id: nil)
    Rails.logger.info "Starting LLMJob", {
      template: template,
      model: model,
      context_keys: context.keys,
      format: format,
      user_id: user_id,
      agent_id: agent_id,
      ai_credential_id: ai_credential_id,
      workspace_id: workspace_id,
      job_id: job_id
    }

    # Load workspace and credential if provided
    workspace = Workspace.find(workspace_id) if workspace_id
    ai_credential = AiCredential.find(ai_credential_id) if ai_credential_id

    # Get the prompt template
    prompt_template = find_prompt_template(template)
    
    # Interpolate context variables into the template
    prompt = interpolate_template(prompt_template, context)
    
    # Call the LLM API with workspace-specific configuration
    response = call_llm_api(model, prompt, format, ai_credential)
    
    # Store the output
    llm_output = store_output(
      template: template,
      model: model,
      context: context,
      format: format,
      prompt: prompt,
      raw_response: response[:raw],
      parsed_output: response[:parsed],
      user_id: user_id,
      agent_id: agent_id,
      ai_credential: ai_credential,
      workspace: workspace
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

  def call_llm_api(model, prompt, format, ai_credential = nil)
    if ai_credential
      # Use workspace-specific credential configuration
      runner = ai_credential.create_job_runner
      client = runner.client
      config = ai_credential.api_config
      
      case ai_credential.ai_provider.slug
      when 'openai'
        call_openai_api(client, prompt, config, format)
      when 'anthropic'
        call_anthropic_api(client, prompt, config, format)
      when 'cohere'
        call_cohere_api(client, prompt, config, format)
      else
        raise "Unsupported provider: #{ai_credential.ai_provider.slug}"
      end
    else
      # Fall back to legacy behavior for backward compatibility
      call_legacy_llm_api(model, prompt, format)
    end
  end

  def call_openai_api(client, prompt, config, format)
    response = client.chat(
      parameters: {
        model: config[:model],
        messages: [{ role: "user", content: prompt }],
        temperature: config[:temperature],
        max_tokens: config[:max_tokens]
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    parsed = format_response(raw, format)

    { raw: raw, parsed: parsed }
  end

  def call_anthropic_api(client, prompt, config, format)
    # Placeholder for Anthropic API integration
    raw = "Anthropic response for: #{prompt[0..50]}..."
    parsed = format_response(raw, format)
    { raw: raw, parsed: parsed }
  end

  def call_cohere_api(client, prompt, config, format)
    # Placeholder for Cohere API integration
    raw = "Cohere response for: #{prompt[0..50]}..."
    parsed = format_response(raw, format)
    { raw: raw, parsed: parsed }
  end

  def call_legacy_llm_api(model, prompt, format)
    # Legacy behavior for backward compatibility
    case format
    when 'json'
      parsed = { "response" => "Mock JSON response for: #{prompt[0..50]}..." }
      raw = parsed.to_json
    when 'markdown'
      raw = "# Mock Markdown Response\n\nFor prompt: #{prompt[0..50]}..."
      parsed = raw
    else
      raw = "Mock text response for: #{prompt[0..50]}..."
      parsed = raw
    end

    { raw: raw, parsed: parsed }
  end

  def format_response(raw_response, format)
    case format
    when 'json'
      begin
        JSON.parse(raw_response)
      rescue JSON::ParserError
        raw_response
      end
    when 'markdown', 'html', 'text'
      raw_response
    else
      raw_response
    end
  end

  def store_output(template:, model:, context:, format:, prompt:, raw_response:, parsed_output:, user_id:, agent_id:, ai_credential: nil, workspace: nil)
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
      ai_credential: ai_credential,
      workspace: workspace,
      job_id: job_id,
      status: 'completed'
    )
  end
end