# frozen_string_literal: true

class LLMOutputsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_llm_output, only: [:show, :feedback, :re_run, :regenerate]

  # GET /llm_outputs
  def index
    @llm_outputs = current_user.llm_outputs.recent.page(params[:page])
  end

  # GET /llm_outputs/:id
  def show
    # Public endpoint for sharing outputs
  end

  # POST /llm_outputs/:id/feedback
  def feedback
    feedback_type = params[:feedback_type]
    
    unless %w[thumbs_up thumbs_down none].include?(feedback_type)
      render json: { error: 'Invalid feedback type' }, status: :bad_request
      return
    end

    @llm_output.set_feedback!(feedback_type, user: current_user)

    respond_to do |format|
      format.json { render json: { status: 'success', feedback: feedback_type } }
      format.html { redirect_back(fallback_location: @llm_output, notice: 'Feedback recorded') }
    end
  rescue => e
    Rails.logger.error "Error setting feedback: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: 'Failed to record feedback' }, status: :internal_server_error }
      format.html { redirect_back(fallback_location: @llm_output, alert: 'Failed to record feedback') }
    end
  end

  # POST /llm_outputs/:id/re_run
  def re_run
    job = @llm_output.re_run!

    respond_to do |format|
      format.json { render json: { status: 'success', message: 'Job queued for re-run', job_id: job.job_id } }
      format.html { redirect_back(fallback_location: @llm_output, notice: 'Job queued for re-run') }
    end
  rescue => e
    Rails.logger.error "Error re-running job: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: 'Failed to queue re-run' }, status: :internal_server_error }
      format.html { redirect_back(fallback_location: @llm_output, alert: 'Failed to queue re-run') }
    end
  end

  # POST /llm_outputs/:id/regenerate
  def regenerate
    new_context = params[:context]&.permit! || @llm_output.context
    new_model = params[:model] || @llm_output.model_name

    job = @llm_output.regenerate!(new_context: new_context, new_model: new_model)

    respond_to do |format|
      format.json { render json: { status: 'success', message: 'Job queued for regeneration', job_id: job.job_id } }
      format.html { redirect_back(fallback_location: @llm_output, notice: 'Job queued for regeneration') }
    end
  rescue => e
    Rails.logger.error "Error regenerating job: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: 'Failed to queue regeneration' }, status: :internal_server_error }
      format.html { redirect_back(fallback_location: @llm_output, alert: 'Failed to queue regeneration') }
    end
  end

  private

  def set_llm_output
    @llm_output = LLMOutput.find(params[:id])
    
    # Only allow users to access their own outputs or public ones
    unless @llm_output.user == current_user || action_name == 'show'
      redirect_to root_path, alert: 'Access denied'
    end
  end
end