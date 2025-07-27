# frozen_string_literal: true

class Api::V1::AiUsageEstimatorController < Api::BaseController

  # POST /api/v1/ai_usage_estimator/estimate
  def estimate
    # Extract parameters from JSON:API format
    data = params.require(:data)
    attributes = data.require(:attributes)
    
    template = attributes.require(:template)
    model = attributes.require(:model)
    context = attributes.fetch(:context, {})
    format = attributes.fetch(:format, 'text')
    ai_credential_id = attributes[:ai_credential_id]

    # Validate format
    unless %w[text json markdown html].include?(format)
      render_jsonapi_error(
        status: :bad_request,
        title: 'Invalid format',
        detail: 'Format must be one of: text, json, markdown, html',
        source: { pointer: '/data/attributes/format' }
      )
      return
    end

    # Validate context is a hash
    unless context.is_a?(Hash)
      render_jsonapi_error(
        status: :bad_request,
        title: 'Invalid context',
        detail: 'Context must be a hash/object',
        source: { pointer: '/data/attributes/context' }
      )
      return
    end

    # Initialize estimator with workspace context
    ai_credential = find_ai_credential(ai_credential_id)
    estimator = AiUsageEstimatorService.new(
      workspace: current_workspace,
      ai_credential: ai_credential
    )

    estimation = estimator.estimate_single(
      template: template,
      model: model,
      context: context,
      format: format
    )

    render json: {
      data: {
        type: 'ai_usage_estimation',
        id: SecureRandom.uuid,
        attributes: estimation
      }
    }, status: :ok

  rescue ActionController::ParameterMissing => e
    render_jsonapi_error(
      status: :bad_request,
      title: 'Missing required parameter',
      detail: "Missing parameter: #{e.param}",
      source: { parameter: e.param.to_s }
    )
  rescue => e
    Rails.logger.error "Error in API AI usage estimation: #{e.message}"
    render_jsonapi_error(
      status: :internal_server_error,
      title: 'Estimation failed',
      detail: e.message
    )
  end

  # POST /api/v1/ai_usage_estimator/batch_estimate
  def batch_estimate
    # Extract parameters from JSON:API format
    data = params.require(:data)
    attributes = data.require(:attributes)
    
    template = attributes.require(:template)
    model = attributes.require(:model)
    inputs = attributes.require(:inputs)
    format = attributes.fetch(:format, 'text')
    ai_credential_id = attributes[:ai_credential_id]

    # Validate format
    unless %w[text json markdown html].include?(format)
      render_jsonapi_error(
        status: :bad_request,
        title: 'Invalid format',
        detail: 'Format must be one of: text, json, markdown, html',
        source: { pointer: '/data/attributes/format' }
      )
      return
    end

    # Validate inputs is an array
    unless inputs.is_a?(Array)
      render_jsonapi_error(
        status: :bad_request,
        title: 'Invalid inputs',
        detail: 'Inputs must be an array of context objects',
        source: { pointer: '/data/attributes/inputs' }
      )
      return
    end

    # Limit batch size for performance
    max_batch_size = 1000
    if inputs.length > max_batch_size
      render_jsonapi_error(
        status: :bad_request,
        title: 'Batch size too large',
        detail: "Maximum #{max_batch_size} inputs allowed. Provided: #{inputs.length}",
        source: { pointer: '/data/attributes/inputs' }
      )
      return
    end

    # Validate each input is a hash
    inputs.each_with_index do |input, index|
      unless input.is_a?(Hash)
        render_jsonapi_error(
          status: :bad_request,
          title: 'Invalid input',
          detail: "Input at index #{index} must be a hash/object",
          source: { pointer: "/data/attributes/inputs/#{index}" }
        )
        return
      end
    end

    # Initialize estimator with workspace context
    ai_credential = find_ai_credential(ai_credential_id)
    estimator = AiUsageEstimatorService.new(
      workspace: current_workspace,
      ai_credential: ai_credential
    )

    batch_estimation = estimator.estimate_batch(
      inputs,
      template: template,
      model: model,
      format: format
    )

    render json: {
      data: {
        type: 'ai_batch_usage_estimation',
        id: SecureRandom.uuid,
        attributes: batch_estimation
      }
    }, status: :ok

  rescue ActionController::ParameterMissing => e
    render_jsonapi_error(
      status: :bad_request,
      title: 'Missing required parameter',
      detail: "Missing parameter: #{e.param}",
      source: { parameter: e.param.to_s }
    )
  rescue => e
    Rails.logger.error "Error in API batch AI usage estimation: #{e.message}"
    render_jsonapi_error(
      status: :internal_server_error,
      title: 'Batch estimation failed',
      detail: e.message
    )
  end

  # GET /api/v1/ai_usage_estimator/models
  def models
    ai_credential_id = params[:ai_credential_id]
    ai_credential = find_ai_credential(ai_credential_id)
    
    estimator = AiUsageEstimatorService.new(
      workspace: current_workspace,
      ai_credential: ai_credential
    )

    available_models = estimator.available_models
    models_with_pricing = available_models.map do |model|
      pricing = estimator.model_pricing(model)
      {
        model: model,
        provider: estimator.send(:get_provider_for_model, model),
        pricing_per_1k_tokens: pricing
      }
    end

    render json: {
      data: {
        type: 'ai_models',
        id: current_workspace&.id || 'default',
        attributes: {
          models: models_with_pricing,
          ai_credential_id: ai_credential&.id
        }
      }
    }, status: :ok

  rescue => e
    Rails.logger.error "Error fetching AI models: #{e.message}"
    render_jsonapi_error(
      status: :internal_server_error,
      title: 'Failed to fetch models',
      detail: e.message
    )
  end

  private

  def current_workspace
    @current_workspace ||= current_user&.current_workspace
  end

  def find_ai_credential(ai_credential_id)
    return nil unless ai_credential_id.present?
    
    if current_workspace
      current_workspace.ai_credentials.find(ai_credential_id)
    else
      current_user.ai_credentials.find(ai_credential_id)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end