# frozen_string_literal: true

# Job runner that provides workspace-scoped LLM job execution
# Usage: LLMJob.for(workspace).run(...)
class AiCredentialJobRunner
  attr_reader :ai_credential, :workspace
  
  def initialize(ai_credential)
    @ai_credential = ai_credential
    @workspace = ai_credential.workspace
  end
  
  # Execute an LLM job with this credential's configuration
  def run(template:, context: {}, format: nil, user: nil, queue: :default)
    # Use credential's preferred settings unless overridden
    format ||= ai_credential.response_format
    
    # Mark credential as used
    ai_credential.mark_used!
    
    # Queue the job with workspace-specific configuration
    LLMJob.perform_later(
      template: template,
      model: ai_credential.preferred_model,
      context: context,
      format: format,
      user_id: user&.id,
      ai_credential_id: ai_credential.id,
      workspace_id: workspace.id,
      queue: queue
    )
  end
  
  # Execute an LLM job synchronously (for testing/debugging)
  def run_sync(template:, context: {}, format: nil, user: nil)
    format ||= ai_credential.response_format
    
    # Mark credential as used
    ai_credential.mark_used!
    
    # Execute the job synchronously
    LLMJob.new.perform(
      template: template,
      model: ai_credential.preferred_model,
      context: context,
      format: format,
      user_id: user&.id,
      ai_credential_id: ai_credential.id,
      workspace_id: workspace.id
    )
  end
  
  # Test the credential by running a simple prompt
  def test_prompt(prompt = "Say hello")
    run_sync(
      template: prompt,
      context: {},
      format: 'text'
    )
  rescue => e
    # Return error information for testing
    {
      success: false,
      error: e.message,
      error_class: e.class.name
    }
  end
  
  # Get provider-specific client for direct API access
  def client
    @client ||= create_client
  end
  
  private
  
  def create_client
    case ai_credential.ai_provider.slug
    when 'openai'
      require 'openai'
      OpenAI::Client.new(
        access_token: ai_credential.api_key,
        uri_base: ai_credential.ai_provider.api_base_url
      )
    when 'anthropic'
      # Would implement Anthropic client
      AnthropicClient.new(
        api_key: ai_credential.api_key,
        base_url: ai_credential.ai_provider.api_base_url
      )
    when 'cohere'
      # Would implement Cohere client
      CohereClient.new(
        api_key: ai_credential.api_key,
        base_url: ai_credential.ai_provider.api_base_url
      )
    else
      raise "Unsupported provider: #{ai_credential.ai_provider.slug}"
    end
  end
end