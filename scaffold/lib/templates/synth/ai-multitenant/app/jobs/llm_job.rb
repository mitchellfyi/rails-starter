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

  # Main API: LLMJob.run(template:, workspace:, context:)
  def self.run(template:, workspace:, context: {}, **options)
    runner = WorkspaceLLMJobRunner.new(workspace)
    runner.run(template: template, context: context, **options)
  end

  # Legacy workspace-scoped runner for backward compatibility
  def self.for(workspace)
    WorkspaceLLMJobRunner.new(workspace)
  end

  def perform(template:, model:, context: {}, format: 'text', user_id: nil, agent_id: nil, ai_credential_id: nil, workspace_id: nil)
    start_time = Time.current
    
    Rails.logger.info "Starting LLMJob", {
      template: template.truncate(100),
      model: model,
      context_keys: context.keys,
      format: format,
      user_id: user_id,
      agent_id: agent_id,
      ai_credential_id: ai_credential_id,
      workspace_id: workspace_id,
      job_id: job_id
    }

    # Load workspace and credential
    workspace = Workspace.find(workspace_id) if workspace_id
    ai_credential = AiCredential.find(ai_credential_id) if ai_credential_id
    user = User.find(user_id) if user_id

    # Create execution record for tracking
    execution = PromptExecution.create!(
      prompt_template: find_prompt_template(template),
      user: user,
      workspace: workspace,
      ai_credential: ai_credential,
      input_context: context,
      status: 'processing',
      started_at: start_time,
      model_used: model
    )

    begin
      # Get the prompt template and render it
      prompt_template = find_prompt_template(template)
      rendered_prompt = interpolate_template(prompt_template, context)
      
      # Update execution with rendered prompt
      execution.update!(rendered_prompt: rendered_prompt)
      
      # Call the LLM API with workspace-specific configuration
      response = call_llm_api(model, rendered_prompt, format, ai_credential)
      
      # Store the output
      llm_output = store_output(
        template: template,
        model: model,
        context: context,
        format: format,
        prompt: rendered_prompt,
        raw_response: response[:raw],
        parsed_output: response[:parsed],
        user_id: user_id,
        agent_id: agent_id,
        ai_credential: ai_credential,
        workspace: workspace,
        execution: execution
      )

      # Update execution as completed
      execution.update!(
        status: 'completed',
        completed_at: Time.current,
        output: response[:parsed],
        tokens_used: response[:usage]&.dig('total_tokens') || 0,
        llm_output: llm_output
      )

      # Track usage for analytics
      track_usage(workspace, ai_credential, response[:usage]) if workspace && response[:usage]

      Rails.logger.info "LLMJob completed successfully", {
        job_id: job_id,
        output_id: llm_output.id,
        execution_id: execution.id,
        duration: (Time.current - start_time).round(2),
        tokens_used: response[:usage]&.dig('total_tokens') || 0,
        response_length: response[:raw]&.length || 0
      }

      llm_output
    rescue => e
      # Update execution as failed
      execution.update!(
        status: 'failed',
        completed_at: Time.current,
        error_message: "#{e.class}: #{e.message}"
      )

      Rails.logger.error "LLMJob failed", {
        job_id: job_id,
        execution_id: execution.id,
        error: e.class.name,
        message: e.message,
        duration: (Time.current - start_time).round(2),
        backtrace: e.backtrace.first(5)
      }
      raise
    end
  end

  private

  def find_prompt_template(template)
    # Try to find a saved template by slug first
    if template.is_a?(String) && !template.include?('{{')
      PromptTemplate.find_by(slug: template)&.prompt_body || template
    else
      template
    end
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
      # Use workspace-specific credential
      call_with_credential(ai_credential, model, prompt, format)
    else
      # Fall back to environment-based configuration
      call_with_env_config(model, prompt, format)
    end
  end

  def call_with_credential(credential, model, prompt, format)
    provider = credential.ai_provider
    
    case provider.slug
    when 'openai'
      call_openai_api(credential.api_key, model, prompt, format)
    when 'anthropic'
      call_anthropic_api(credential.api_key, model, prompt, format)
    else
      raise "Unsupported provider: #{provider.slug}"
    end
  end

  def call_with_env_config(model, prompt, format)
    # Determine provider based on model name
    case model
    when /^gpt-/
      call_openai_api(ENV['OPENAI_API_KEY'], model, prompt, format)
    when /^claude-/
      call_anthropic_api(ENV['ANTHROPIC_API_KEY'], model, prompt, format)
    else
      raise "Unable to determine provider for model: #{model}"
    end
  end

  def call_openai_api(api_key, model, prompt, format)
    require 'openai'
    
    client = OpenAI::Client.new(access_token: api_key)
    
    messages = [{ role: 'user', content: prompt }]
    
    response = client.chat(
      parameters: {
        model: model,
        messages: messages,
        temperature: 0.7,
        max_tokens: 4096
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    usage = response['usage']
    
    {
      raw: content,
      parsed: parse_output(content, format),
      usage: usage
    }
  end

  def call_anthropic_api(api_key, model, prompt, format)
    # Implementation for Anthropic API would go here
    # For now, return a placeholder
    {
      raw: "Anthropic API response placeholder",
      parsed: parse_output("Anthropic API response placeholder", format),
      usage: { 'total_tokens' => 50 }
    }
  end

  def parse_output(content, format)
    case format
    when 'json'
      begin
        JSON.parse(content)
      rescue JSON::ParserError
        content
      end
    when 'markdown'
      content
    when 'html'
      content
    else
      content
    end
  end

  def store_output(template:, model:, context:, format:, prompt:, raw_response:, parsed_output:, user_id: nil, agent_id: nil, ai_credential: nil, workspace: nil, execution: nil)
    LLMOutput.create!(
      template_name: template.is_a?(String) ? template.truncate(255) : 'Dynamic Template',
      model_name: model,
      context: context,
      format: format,
      prompt: prompt,
      raw_response: raw_response,
      parsed_output: parsed_output,
      status: 'completed',
      user_id: user_id,
      agent_id: agent_id,
      ai_credential: ai_credential,
      workspace: workspace,
      prompt_execution: execution,
      job_id: job_id
    )
  end

  def track_usage(workspace, ai_credential, usage)
    return unless usage && usage['total_tokens']

    # Create or update daily usage summary
    date = Time.current.to_date
    summary = AiUsageSummary.find_or_create_by(
      workspace: workspace,
      ai_credential: ai_credential,
      date: date
    ) do |s|
      s.requests_count = 0
      s.tokens_used = 0
      s.estimated_cost = 0.0
    end

    # Update counters
    summary.increment!(:requests_count)
    summary.increment!(:tokens_used, usage['total_tokens'])
    
    # Estimate cost (rough calculation, adjust based on actual pricing)
    cost_per_token = case ai_credential.ai_provider.slug
                    when 'openai'
                      0.00003  # $0.03 per 1K tokens for GPT-4
                    when 'anthropic'
                      0.00008  # $0.08 per 1K tokens for Claude
                    else
                      0.00002  # Default estimate
                    end
    
    estimated_cost = usage['total_tokens'] * cost_per_token
    summary.increment!(:estimated_cost, estimated_cost)
  end
end