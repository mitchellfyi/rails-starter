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

  def perform(template:, model:, context: {}, format: 'text', user_id: nil, agent_id: nil)
    Rails.logger.info "Starting LLMJob", {
      template: template,
      model: model,
      context_keys: context.keys,
      format: format,
      user_id: user_id,
      agent_id: agent_id,
      job_id: job_id
    }

    # Get the prompt template
    prompt_template = find_prompt_template(template)
    
    # Interpolate context variables into the template
    prompt = interpolate_template(prompt_template, context)
    
    # Call the LLM API
    response = call_llm_api(model, prompt, format)
    
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
    # This would integrate with actual LLM providers (OpenAI, Claude, etc.)
    # For now, return a mock response
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

    {
      raw: raw,
      parsed: parsed
    }
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
end