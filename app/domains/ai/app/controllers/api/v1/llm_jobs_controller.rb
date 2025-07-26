# frozen_string_literal: true

class Api::V1::LLMJobsController < ApplicationController
  before_action :authenticate_user!

  # POST /api/v1/llm_jobs
  def create
    template = params.require(:template)
    model = params.require(:model)
    context = params.fetch(:context, {})
    format = params.fetch(:format, 'text')

    # Validate format
    unless %w[text json markdown html].include?(format)
      render json: { error: 'Invalid format. Must be one of: text, json, markdown, html' }, 
             status: :bad_request
      return
    end

    # Validate context is a hash
    unless context.is_a?(Hash)
      render json: { error: 'Context must be a hash/object' }, status: :bad_request
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

    render json: {
      job_id: job.job_id,
      output_id: llm_output.id,
      status: 'queued',
      estimated_completion: 30.seconds.from_now.iso8601
    }, status: :created

  rescue ActionController::ParameterMissing => e
    render json: { error: "Missing required parameter: #{e.param}" }, status: :bad_request
  rescue => e
    Rails.logger.error "Error creating LLM job: #{e.message}"
    render json: { error: 'Failed to queue job' }, status: :internal_server_error
  end
end