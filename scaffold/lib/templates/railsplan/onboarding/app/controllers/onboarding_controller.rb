# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_onboarding_progress
  before_action :set_step_handler

  def index
    # Redirect to current step if onboarding is in progress
    if @onboarding_progress.incomplete?
      redirect_to onboarding_step_path(@onboarding_progress.next_step)
    else
      redirect_to root_path, notice: 'Onboarding already completed!'
    end
  end

  def show
    @step = params[:step]
    
    # Check if step is valid and available
    unless @step_handler.step_available?(@step)
      redirect_to onboarding_path, alert: 'Step not available'
      return
    end

    # Get data for the current step
    @step_data = @step_handler.get_step_data(@step)
    
    # Render the appropriate step view
    case @step
    when 'complete'
      render 'complete'
    else
      render 'show'
    end
  end

  def update
    @step = params[:step]
    
    unless @step_handler.step_available?(@step)
      redirect_to onboarding_path, alert: 'Step not available'
      return
    end

    if @step_handler.handle_step(@step, step_params)
      # Move to next step
      next_step = @onboarding_progress.reload.next_step
      
      if next_step == 'complete'
        redirect_to onboarding_step_path('complete'), notice: 'Onboarding completed successfully!'
      else
        redirect_to onboarding_step_path(next_step), notice: 'Step completed!'
      end
    else
      @step_data = @step_handler.get_step_data(@step)
      flash.now[:alert] = 'Please complete the required fields or click skip.'
      render 'show'
    end
  end

  def skip
    current_user.skip_onboarding!
    redirect_to root_path, notice: 'Onboarding skipped. You can access setup options from your account settings.'
  end

  def resume
    current_user.start_onboarding!
    redirect_to onboarding_path, notice: 'Welcome back! Let\'s continue your setup.'
  end

  private

  def set_onboarding_progress
    current_user.start_onboarding! unless current_user.onboarding_progress
    @onboarding_progress = current_user.onboarding_progress
  end

  def set_step_handler
    @step_handler = OnboardingStepHandler.new(current_user)
  end

  def step_params
    case params[:step]
    when 'create_workspace'
      params.permit(workspace: [:name, :description])
    when 'invite_colleagues'
      params.permit(:workspace_id, invitations: [:email, :role])
    when 'connect_billing'
      params.permit(billing: [:payment_method, :plan])
    when 'connect_ai'
      params.permit(ai: [:provider, :api_key])
    else
      {}
    end
  end
end