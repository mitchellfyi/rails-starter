# frozen_string_literal: true

# Workspace-scoped LLM job runner with enhanced multitenant features
# Usage: LLMJob.run(template:, workspace:, context:) or WorkspaceLLMJobRunner.new(workspace).run(...)
class WorkspaceLLMJobRunner
  attr_reader :workspace
  
  def initialize(workspace)
    @workspace = workspace
    raise ArgumentError, "Workspace cannot be nil" unless workspace
  end
  
  # Main API: run LLM job with automatic provider selection
  def run(template:, context: {}, format: 'text', user: nil, provider: nil, model: nil, queue: :default)
    validate_inputs!(template, context, format)
    
    # Find the best credential for the request
    credential = find_best_credential(provider, model)
    
    unless credential
      available_providers = available_providers()
      raise ArgumentError, "No active AI credential found for provider '#{provider || 'any'}' in workspace '#{workspace.name}'. Available providers: #{available_providers.join(', ')}"
    end
    
    # Use the selected model or fall back to credential's preferred model
    selected_model = model || credential.preferred_model
    
    # Validate model is supported
    unless credential.supports_model?(selected_model)
      raise ArgumentError, "Model '#{selected_model}' is not supported by provider '#{credential.ai_provider.slug}'. Supported models: #{credential.ai_provider.supported_models.join(', ')}"
    end
    
    # Mark credential as used
    credential.mark_as_used!
    
    # Execute the job
    LLMJob.perform_later(
      template: template,
      model: selected_model,
      context: context,
      format: format,
      user_id: user&.id,
      ai_credential_id: credential.id,
      workspace_id: workspace.id
    )
  end
  
  # Synchronous execution for testing and immediate results
  def run_sync(template:, context: {}, format: 'text', user: nil, provider: nil, model: nil)
    validate_inputs!(template, context, format)
    
    credential = find_best_credential(provider, model)
    unless credential
      raise ArgumentError, "No active AI credential found for provider '#{provider || 'any'}' in workspace '#{workspace.name}'"
    end
    
    selected_model = model || credential.preferred_model
    credential.mark_as_used!
    
    # Execute synchronously
    job = LLMJob.new
    job.perform(
      template: template,
      model: selected_model,
      context: context,
      format: format,
      user_id: user&.id,
      ai_credential_id: credential.id,
      workspace_id: workspace.id
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
  
  # Get all available models across all providers
  def available_models
    models = {}
    workspace.ai_credentials.active.includes(:ai_provider).each do |credential|
      provider_slug = credential.ai_provider.slug
      models[provider_slug] ||= []
      models[provider_slug].concat(credential.ai_provider.supported_models)
    end
    models.each { |k, v| v.uniq! }
    models
  end
  
  # Get credential for a specific provider
  def credential_for(provider_slug, model: nil)
    find_best_credential(provider_slug, model)
  end
  
  # Test connectivity for all credentials
  def test_all_credentials
    results = {}
    
    workspace.ai_credentials.active.includes(:ai_provider).each do |credential|
      provider_slug = credential.ai_provider.slug
      results[provider_slug] ||= []
      results[provider_slug] << {
        credential_name: credential.name,
        credential_id: credential.id,
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
  
  # Get usage statistics for this workspace
  def usage_stats(date_range = 30.days.ago..Time.current)
    AiUsageSummary.total_usage_for_workspace(workspace, date_range)
  end
  
  # Get daily usage breakdown
  def daily_usage(days = 30)
    AiUsageSummary.daily_usage_for_workspace(workspace, days)
  end
  
  # Get provider breakdown
  def provider_breakdown(date_range = nil)
    AiUsageSummary.provider_breakdown_for_workspace(workspace, date_range)
  end
  
  # Get model breakdown
  def model_breakdown(date_range = nil)
    AiUsageSummary.model_breakdown_for_workspace(workspace, date_range)
  end
  
  # Check if workspace is within usage limits
  def within_limits?
    return true unless workspace.respond_to?(:ai_usage_limit) && workspace.ai_usage_limit
    
    monthly_usage = AiUsageSummary.where(
      workspace: workspace,
      date: Time.current.beginning_of_month.to_date..Time.current.to_date
    ).sum(:tokens_used)
    
    monthly_usage < workspace.ai_usage_limit
  end
  
  # Get remaining usage for the month
  def remaining_usage
    return Float::INFINITY unless workspace.respond_to?(:ai_usage_limit) && workspace.ai_usage_limit
    
    monthly_usage = AiUsageSummary.where(
      workspace: workspace,
      date: Time.current.beginning_of_month.to_date..Time.current.to_date
    ).sum(:tokens_used)
    
    [workspace.ai_usage_limit - monthly_usage, 0].max
  end
  
  # Estimate cost for a template
  def estimate_cost(template:, context: {}, provider: nil, model: nil)
    credential = find_best_credential(provider, model)
    return { error: "No credential available" } unless credential
    
    # Simple token estimation (4 characters ≈ 1 token)
    rendered_template = interpolate_template(template, context)
    estimated_tokens = (rendered_template.length / 4.0).ceil
    
    # Get cost per token for this credential
    cost_per_token = get_cost_per_token(credential)
    estimated_cost = estimated_tokens * cost_per_token
    
    {
      estimated_tokens: estimated_tokens,
      estimated_cost: estimated_cost.round(6),
      provider: credential.ai_provider.slug,
      model: model || credential.preferred_model,
      credential_name: credential.name
    }
  end
  
  # Batch execution with provider distribution
  def run_batch(jobs, distribute: true)
    return [] if jobs.empty?
    
    if distribute && available_providers.size > 1
      # Distribute jobs across available providers
      distributed_jobs = distribute_jobs(jobs)
      distributed_jobs.map { |job_config| run(**job_config) }
    else
      # Execute all jobs with best available credential
      jobs.map { |job_config| run(**job_config) }
    end
  end
  
  private
  
  def validate_inputs!(template, context, format)
    raise ArgumentError, "Template cannot be blank" if template.blank?
    raise ArgumentError, "Context must be a Hash" unless context.is_a?(Hash)
    raise ArgumentError, "Invalid format: #{format}" unless %w[text json markdown html].include?(format)
  end
  
  def find_best_credential(provider_slug, preferred_model = nil)
    if provider_slug
      # Find credential for specific provider
      credential = workspace.ai_credentials
                           .joins(:ai_provider)
                           .where(ai_providers: { slug: provider_slug }, active: true)
      
      # If a specific model is requested, find credential that supports it
      if preferred_model
        model_credential = credential.joins(:ai_provider)
                                    .where("? = ANY(ai_providers.supported_models)", preferred_model)
                                    .where(preferred_model: preferred_model)
                                    .first
        
        # Fall back to any credential that supports the model
        model_credential ||= credential.joins(:ai_provider)
                                      .where("? = ANY(ai_providers.supported_models)", preferred_model)
                                      .first
        
        return model_credential if model_credential
      end
      
      # Get default credential or most recently used
      credential.where(is_default: true).first || credential.order(last_used_at: :desc).first
    else
      # No specific provider requested - find best available credential
      # Prefer default credentials, then most recently used
      workspace.ai_credentials
               .active
               .order(is_default: :desc, last_used_at: :desc, created_at: :desc)
               .first
    end
  end
  
  def interpolate_template(template, context)
    result = template.to_s.dup
    context.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end
  
  def get_cost_per_token(credential)
    case credential.ai_provider.slug
    when 'openai'
      case credential.preferred_model
      when 'gpt-4', 'gpt-4-turbo'
        0.00006  # $0.06 per 1K tokens
      when 'gpt-3.5-turbo'
        0.000002  # $0.002 per 1K tokens
      else
        0.00003   # Default OpenAI estimate
      end
    when 'anthropic'
      case credential.preferred_model
      when 'claude-3-opus'
        0.000075  # $0.075 per 1K tokens
      when 'claude-3-sonnet'
        0.000015  # $0.015 per 1K tokens
      when 'claude-3-haiku'
        0.00000125  # $0.00125 per 1K tokens
      else
        0.000015   # Default Anthropic estimate
      end
    else
      0.00002  # Generic estimate
    end
  end
  
  def distribute_jobs(jobs)
    providers = available_providers
    return jobs if providers.size <= 1
    
    # Simple round-robin distribution
    jobs.map.with_index do |job_config, index|
      provider = providers[index % providers.size]
      job_config.merge(provider: provider)
    end
  end
end