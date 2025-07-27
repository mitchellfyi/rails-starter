# frozen_string_literal: true

class Api::V1::LLMJobsController < Api::BaseController

  # POST /api/v1/llm_jobs
  def create
    # Extract parameters from JSON:API format
    data = params.require(:data)
    attributes = data.require(:attributes)
    
    template = attributes.require(:template)
    model = attributes.require(:model)
    context = attributes.fetch(:context, {})
    format = attributes.fetch(:format, 'text')

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

    # Queue the job
    job = LLMJob.perform_later(
      template: template,
      model: model,
      context: context,
      format: format,
      user_id: current_user.id
    )

    # Create a pending LLMOutput record
    llm_output = LLMOutput.create!(
      template_name: template,
      model_name: model,
      context: context,
      format: format,
      status: 'pending',
      job_id: job.job_id,
      user_id: current_user.id
    )

    render_jsonapi_resource(llm_output, LLMOutputSerializer, status: :created)

  rescue ActionController::ParameterMissing => e
    render_jsonapi_error(
      status: :bad_request,
      title: 'Missing required parameter',
      detail: "Missing parameter: #{e.param}",
      source: { parameter: e.param.to_s }
    )
  rescue => e
    Rails.logger.error "Error creating LLM job: #{e.message}"
    render_jsonapi_error(
      status: :internal_server_error,
      title: 'Failed to queue job',
      detail: e.message
    )
  end
end