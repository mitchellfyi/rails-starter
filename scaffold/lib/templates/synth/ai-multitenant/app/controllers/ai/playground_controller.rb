# frozen_string_literal: true

class Ai::PlaygroundController < Ai::BaseController
  before_action :check_playground_enabled

  def index
    @available_models = current_workspace_runner.available_models
    @recent_executions = recent_playground_executions
    @saved_templates = saved_templates
    @usage_stats = current_workspace_runner.usage_stats(7.days.ago..Time.current)
  end

  def execute
    template = params[:template]
    context = parse_context(params[:context])
    provider = params[:provider].presence
    model = params[:model].presence
    format = params[:format] || 'text'

    # Validate inputs
    if template.blank?
      return render json: { error: "Template cannot be blank" }, status: 422
    end

    begin
      # Get cost estimate first
      estimate = current_workspace_runner.estimate_cost(
        template: template,
        context: context,
        provider: provider,
        model: model
      )

      if estimate[:error]
        return render json: { error: estimate[:error] }, status: 422
      end

      # Check usage limits
      unless current_workspace_runner.within_limits?
        return render json: { 
          error: "Workspace has exceeded AI usage limits for this month",
          remaining_usage: current_workspace_runner.remaining_usage
        }, status: 429
      end

      # Execute synchronously for playground (immediate feedback)
      result = current_workspace_runner.run_sync(
        template: template,
        context: context,
        format: format,
        user: current_user,
        provider: provider,
        model: model
      )

      # Save to playground history if requested
      if params[:save_to_history].present?
        save_playground_execution(template, context, provider, model, format, result)
      end

      render json: {
        success: true,
        result: {
          output: result.parsed_output,
          raw_output: result.raw_response,
          model_used: result.model_name,
          provider_used: result.ai_credential&.ai_provider&.name,
          tokens_used: result.prompt_execution&.tokens_used,
          response_time: result.prompt_execution&.duration,
          estimated_cost: estimate[:estimated_cost]
        },
        execution_id: result.prompt_execution&.id
      }

    rescue => e
      Rails.logger.error "Playground execution failed: #{e.message}", {
        template: template.truncate(100),
        context: context,
        provider: provider,
        model: model,
        user_id: current_user.id,
        workspace_id: current_workspace.id,
        error: e.class.name,
        backtrace: e.backtrace.first(3)
      }

      render json: { 
        error: "Execution failed: #{e.message}",
        error_type: e.class.name
      }, status: 500
    end
  end

  def save_template
    name = params[:name]
    template = params[:template]
    description = params[:description]
    tags = params[:tags]&.split(',')&.map(&:strip) || []

    if name.blank? || template.blank?
      return render json: { error: "Name and template are required" }, status: 422
    end

    begin
      prompt_template = current_workspace.prompt_templates.create!(
        name: name,
        description: description,
        prompt_body: template,
        tags: tags,
        active: true,
        created_by: current_user
      )

      render json: {
        success: true,
        template: {
          id: prompt_template.id,
          name: prompt_template.name,
          slug: prompt_template.slug,
          description: prompt_template.description
        }
      }
    rescue => e
      render json: { error: "Failed to save template: #{e.message}" }, status: 422
    end
  end

  def load_template
    template = current_workspace.prompt_templates.find_by(id: params[:template_id])
    
    unless template
      return render json: { error: "Template not found" }, status: 404
    end

    render json: {
      success: true,
      template: {
        id: template.id,
        name: template.name,
        prompt_body: template.prompt_body,
        description: template.description,
        variable_names: template.variable_names,
        output_format: template.output_format
      }
    }
  end

  def compare_models
    template = params[:template]
    context = parse_context(params[:context])
    models = params[:models] || []

    if template.blank? || models.empty?
      return render json: { error: "Template and models are required" }, status: 422
    end

    results = []
    
    models.each do |model_config|
      provider = model_config['provider']
      model = model_config['model']
      
      begin
        result = current_workspace_runner.run_sync(
          template: template,
          context: context,
          provider: provider,
          model: model,
          user: current_user
        )

        results << {
          provider: provider,
          model: model,
          output: result.parsed_output,
          tokens_used: result.prompt_execution&.tokens_used,
          response_time: result.prompt_execution&.duration,
          success: true
        }
      rescue => e
        results << {
          provider: provider,
          model: model,
          error: e.message,
          success: false
        }
      end
    end

    render json: {
      success: true,
      comparisons: results
    }
  end

  def usage_info
    stats = current_workspace_runner.usage_stats(30.days.ago..Time.current)
    remaining = current_workspace_runner.remaining_usage
    
    render json: {
      success: true,
      usage: {
        current_month: stats,
        remaining_tokens: remaining,
        within_limits: current_workspace_runner.within_limits?,
        providers: current_workspace_runner.provider_breakdown(30.days.ago..Time.current)
      }
    }
  end

  private

  def check_playground_enabled
    unless Rails.application.config.ai_multitenant.playground_enabled
      redirect_to root_path, alert: "AI Playground is not enabled."
    end
  end

  def parse_context(context_param)
    return {} if context_param.blank?

    case context_param
    when String
      begin
        JSON.parse(context_param)
      rescue JSON::ParserError
        # Try to parse as key=value pairs
        pairs = context_param.split(',').map(&:strip)
        result = {}
        pairs.each do |pair|
          key, value = pair.split('=', 2)
          result[key.strip] = value&.strip if key.present?
        end
        result
      end
    when Hash
      context_param
    else
      {}
    end
  end

  def recent_playground_executions(limit = 10)
    PromptExecution.joins(:workspace)
                   .where(workspace: current_workspace, user: current_user)
                   .where('created_at > ?', 7.days.ago)
                   .order(created_at: :desc)
                   .limit(limit)
                   .includes(:ai_credential, :llm_output, :prompt_template)
  end

  def saved_templates
    current_workspace.prompt_templates
                    .where(active: true)
                    .order(:name)
                    .limit(20)
  end

  def save_playground_execution(template, context, provider, model, format, result)
    # Save execution to playground history
    # This could be a separate model or just tagged executions
    result.prompt_execution&.update(
      playground_session: true,
      session_data: {
        template: template.truncate(1000),
        context: context,
        provider: provider,
        model: model,
        format: format
      }
    )
  end
end