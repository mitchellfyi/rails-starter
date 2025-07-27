# frozen_string_literal: true

class PromptExecutionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prompt_template
  before_action :set_prompt_execution, only: [:show, :destroy]

  def index
    @executions = @prompt_template.prompt_executions.recent.includes(:user)
    @executions = @executions.where(status: params[:status]) if params[:status].present?
  end

  def show
  end

  def create
    context = params[:context].present? ? JSON.parse(params[:context]) : {}
    
    # Validate context
    missing_vars = @prompt_template.validate_context(context)
    if missing_vars != true
      return render json: { 
        error: "Missing required variables: #{missing_vars.join(', ')}" 
      }, status: :unprocessable_entity
    end

    @execution = @prompt_template.prompt_executions.build(
      user: current_user,
      workspace: @prompt_template.workspace,
      input_context: context,
      rendered_prompt: @prompt_template.render_with_context(context),
      status: 'pending'
    )

    if @execution.save
      # Execute the prompt if it's not just a preview
      if params[:execute] == 'true'
        @execution.execute_with_llm!(params[:model])
        render json: { 
          execution_id: @execution.id,
          status: @execution.status,
          message: 'Execution queued successfully' 
        }
      else
        # Just create a preview execution
        @execution.update!(status: 'preview')
        render json: {
          execution_id: @execution.id,
          rendered_prompt: @execution.rendered_prompt,
          message: 'Preview created successfully'
        }
      end
    else
      render json: { error: @execution.errors.full_messages }, status: :unprocessable_entity
    end
  rescue JSON::ParserError
    render json: { error: 'Invalid JSON in context' }, status: :unprocessable_entity
  end

  def destroy
    @execution.destroy
    redirect_to prompt_template_path(@prompt_template), notice: 'Execution deleted successfully.'
  end

  private

  def set_prompt_template
    @prompt_template = PromptTemplate.find(params[:prompt_template_id])
  end

  def set_prompt_execution
    @execution = @prompt_template.prompt_executions.find(params[:id])
  end
end