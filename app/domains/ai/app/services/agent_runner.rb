# frozen_string_literal: true

require Rails.root.join('lib', 'api_client_factory') if defined?(Rails)

class AgentRunner
  include ActiveSupport::Configurable
  
  attr_reader :agent, :user, :context, :streaming_enabled

  def initialize(agent_id, user: nil, context: {})
    @agent = find_agent(agent_id)
    @user = user
    @context = context.with_indifferent_access
    @streaming_enabled = @agent.streaming_enabled
    @webhook_enabled = @agent.webhook_enabled
    
    validate_agent_ready!
  end

  # Main entry point for running an agent
  def self.run(agent_id, user_input, user: nil, context: {}, streaming: false, &block)
    runner = new(agent_id, user: user, context: context)
    runner.run(user_input, streaming: streaming, &block)
  end

  # Execute the agent with user input
  def run(user_input, streaming: false, &block)
    Rails.logger.info "AgentRunner executing", {
      agent_id: agent.id,
      agent_name: agent.name,
      user_id: user&.id,
      streaming: streaming || streaming_enabled,
      context_keys: context.keys
    }

    # Merge user input into context
    execution_context = context.merge(user_input: user_input)
    
    # Build enriched context with MCP data if available
    enriched_context = build_mcp_context(execution_context)
    
    # Get compiled system prompt
    system_prompt = agent.compiled_system_prompt(enriched_context)
    
    # Prepare the API call
    api_params = build_api_params(system_prompt, user_input, enriched_context)
    
    # Create execution record
    execution = create_execution_record(user_input, enriched_context)
    
    begin
      if streaming || streaming_enabled
        # Stream the response
        stream_response(api_params, execution, &block)
      else
        # Get synchronous response
        synchronous_response(api_params, execution)
      end
    rescue => error
      handle_execution_error(execution, error)
      raise
    end
  end

  # Execute agent asynchronously
  def run_async(user_input, context: {})
    merged_context = self.context.merge(context).merge(user_input: user_input)
    
    LLMJob.perform_later(
      template: agent.prompt_template&.slug || 'agent_template',
      model: agent.model_name,
      context: merged_context,
      format: 'text',
      user_id: user&.id,
      agent_id: agent.id
    )
  end

  # Check if streaming is available for this agent
  def streaming_available?
    streaming_enabled && supports_streaming?
  end

  # Get agent configuration
  def agent_config
    agent.effective_config
  end

  private

  def find_agent(agent_id)
    if agent_id.is_a?(String)
      # Try to find by slug first, then by ID
      Agent.find_by(slug: agent_id) || Agent.find(agent_id)
    else
      Agent.find(agent_id)
    end
  rescue ActiveRecord::RecordNotFound
    raise ArgumentError, "Agent not found: #{agent_id}"
  end

  def validate_agent_ready!
    raise ArgumentError, "Agent is not ready to run" unless agent.ready?
  end

  def build_mcp_context(base_context)
    return base_context unless agent.workspace.respond_to?(:mcp_workspace_service)
    
    # Use existing MCP workspace service if available
    mcp_service = agent.workspace.mcp_workspace_service
    return base_context unless mcp_service
    
    begin
      mcp_context = mcp_service.get_context(base_context)
      base_context.merge(mcp_context)
    rescue => error
      Rails.logger.warn "MCP context building failed", { error: error.message, agent_id: agent.id }
      base_context
    end
  end

  def build_api_params(system_prompt, user_input, context)
    {
      model: agent.model_name,
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_input }
      ],
      temperature: agent.temperature,
      max_tokens: agent.max_tokens,
      stream: streaming_enabled
    }
  end

  def create_execution_record(user_input, context)
    PromptExecution.create!(
      prompt_template: agent.prompt_template,
      user: user,
      workspace: agent.workspace,
      input_context: context.merge(user_input: user_input),
      rendered_prompt: user_input,
      status: 'processing'
    )
  end

  def stream_response(api_params, execution, &block)
    response_chunks = []
    
    client = get_api_client
    
    client.chat(api_params.merge(stream: true)) do |chunk|
      content = extract_content_from_chunk(chunk)
      
      if content.present?
        response_chunks << content
        
        # Yield to the block if provided
        yield(content, :chunk) if block_given?
        
        # Send to webhook if configured
        send_webhook_chunk(content) if webhook_enabled?
      end
    end
    
    # Finalize response
    full_response = response_chunks.join
    finalize_execution(execution, full_response)
    
    yield(full_response, :complete) if block_given?
    
    full_response
  end

  def synchronous_response(api_params, execution)
    client = get_api_client
    response = client.chat(api_params)
    
    content = extract_content_from_response(response)
    finalize_execution(execution, content)
    
    # Send to webhook if configured
    send_webhook_response(content) if webhook_enabled?
    
    content
  end

  def finalize_execution(execution, response)
    execution.update!(
      status: 'completed',
      response: response,
      completed_at: Time.current
    )
    
    # Also create LLMOutput record for consistency
    LLMOutput.create!(
      template_name: agent.prompt_template&.slug || 'agent_template',
      model_name: agent.model_name,
      context: execution.input_context,
      raw_response: response,
      formatted_response: response,
      format: 'text',
      status: 'completed',
      user: user,
      agent: agent,
      prompt_execution: execution,
      job_id: SecureRandom.uuid
    )
  end

  def handle_execution_error(execution, error)
    execution.update!(
      status: 'failed',
      error_message: error.message,
      completed_at: Time.current
    )
    
    Rails.logger.error "AgentRunner execution failed", {
      agent_id: agent.id,
      execution_id: execution.id,
      error: error.message,
      backtrace: error.backtrace&.first(5)
    }
  end

  def get_api_client
    case agent.model_name
    when /^gpt-/
      ApiClientFactory.openai_client(api_key: agent.api_key)
    when /^claude-/
      ApiClientFactory.anthropic_client(api_key: agent.api_key)
    else
      raise ArgumentError, "Unsupported model: #{agent.model_name}"
    end
  end

  def extract_content_from_chunk(chunk)
    # Handle different chunk formats based on provider
    case agent.model_name
    when /^gpt-/
      chunk.dig('choices', 0, 'delta', 'content')
    when /^claude-/
      chunk.dig('delta', 'text')
    else
      chunk.to_s
    end
  end

  def extract_content_from_response(response)
    # Handle different response formats based on provider
    case agent.model_name
    when /^gpt-/
      response.dig('choices', 0, 'message', 'content')
    when /^claude-/
      response.dig('content', 0, 'text')
    else
      response.to_s
    end
  end

  def supports_streaming?
    # Most modern models support streaming
    true
  end

  def webhook_enabled?
    @webhook_enabled && agent.webhook_config['url'].present?
  end

  def send_webhook_chunk(content)
    return unless webhook_enabled?
    
    webhook_url = agent.webhook_config['url']
    webhook_data = {
      agent_id: agent.id,
      agent_name: agent.name,
      type: 'chunk',
      content: content,
      timestamp: Time.current.iso8601,
      user_id: user&.id
    }
    
    send_webhook_request(webhook_url, webhook_data)
  end

  def send_webhook_response(content)
    return unless webhook_enabled?
    
    webhook_url = agent.webhook_config['url']
    webhook_data = {
      agent_id: agent.id,
      agent_name: agent.name,
      type: 'complete',
      content: content,
      timestamp: Time.current.iso8601,
      user_id: user&.id
    }
    
    send_webhook_request(webhook_url, webhook_data)
  end

  def send_webhook_request(url, data)
    # This would typically use a background job for reliability
    begin
      # Use a simple HTTP client for webhook delivery
      # In production, you'd want proper retry logic and queue this
      Rails.logger.info "Sending webhook", { url: url, agent_id: agent.id }
      
      # Placeholder for actual HTTP request
      # Net::HTTP.post_form(URI(url), data)
    rescue => error
      Rails.logger.warn "Webhook delivery failed", { url: url, error: error.message }
    end
  end
end