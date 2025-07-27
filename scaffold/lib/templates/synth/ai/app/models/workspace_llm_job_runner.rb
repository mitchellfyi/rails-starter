# frozen_string_literal: true

# Workspace-scoped LLM job runner
# Usage: LLMJob.for(workspace).run(...)
class WorkspaceLLMJobRunner
  attr_reader :workspace
  
  def initialize(workspace)
    @workspace = workspace
  end
  
  # Run LLM job with automatic provider selection
  def run(template:, context: {}, format: 'text', user: nil, provider: 'openai', model: nil, queue: :default)
    credential = find_credential(provider, model)
    
    unless credential
      raise "No active AI credential found for provider '#{provider}' in workspace '#{workspace.name}'"
    end
    
    credential.create_job_runner.run(
      template: template,
      context: context,
      format: format,
      user: user,
      queue: queue
    )
  end
  
  # List available providers for this workspace
  def available_providers
    workspace.ai_credentials
            .joins(:ai_provider)
            .where(active: true)
            .group_by { |cred| cred.ai_provider.slug }
            .keys
  end
  
  # Get credential for a specific provider
  def credential_for(provider_slug, model: nil)
    find_credential(provider_slug, model)
  end
  
  # Test connectivity for all credentials
  def test_all_credentials
    results = {}
    
    workspace.ai_credentials.active.includes(:ai_provider).each do |credential|
      provider_slug = credential.ai_provider.slug
      results[provider_slug] ||= []
      results[provider_slug] << {
        credential_name: credential.name,
        test_result: credential.test_connection
      }
    end
    
    results
  end
  
  # Get the best credential for a provider (default first, then most recently used)
  def best_credential_for(provider_slug)
    AiCredential.best_for(workspace, provider_slug)
  end
  
  # Check if workspace has any AI credentials configured
  def configured?
    workspace.ai_credentials.active.exists?
  end
  
  private
  
  def find_credential(provider_slug, preferred_model = nil)
    credential = workspace.ai_credentials
                         .joins(:ai_provider)
                         .where(ai_providers: { slug: provider_slug }, active: true)
    
    # If a specific model is requested, find credential that supports it
    if preferred_model
      credential = credential.where(preferred_model: preferred_model).first ||
                  credential.joins(:ai_provider)
                            .where("? = ANY(ai_providers.supported_models)", preferred_model)
                            .first
    else
      # Get default credential or any active one
      credential = credential.where(is_default: true).first || credential.first
    end
    
    credential
  end
end