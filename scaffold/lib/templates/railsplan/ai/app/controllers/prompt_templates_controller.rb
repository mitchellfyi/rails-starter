# frozen_string_literal: true

class PromptTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_prompt_template, only: [:show, :edit, :update, :destroy, :preview, :diff, :publish, :create_version]
  before_action :set_workspace, if: -> { params[:workspace_id].present? }

  def index
    @prompt_templates = current_scope.includes(:created_by, :versions)
    @prompt_templates = @prompt_templates.by_tag(params[:tag]) if params[:tag].present?
    @prompt_templates = @prompt_templates.by_output_format(params[:output_format]) if params[:output_format].present?
    @prompt_templates = @prompt_templates.where(published: true) if params[:published_only] == 'true'
    @prompt_templates = @prompt_templates.order(:name, :version)

    respond_to do |format|
      format.html
      format.json { render json: @prompt_templates.map { |t| template_summary(t) } }
    end
  end

  def show
    @executions = @prompt_template.prompt_executions.recent.limit(10)
    @versions = @prompt_template.versions.order(created_at: :desc).limit(10)
    @version_history = @prompt_template.version_history.order(:created_at)

    respond_to do |format|
      format.html
      format.json { render json: template_detail(@prompt_template) }
    end
  end

  def new
    @prompt_template = current_scope.build
  end

  def create
    @prompt_template = current_scope.build(prompt_template_params)
    @prompt_template.created_by = current_user

    if @prompt_template.save
      redirect_to prompt_template_path(@prompt_template), notice: 'Prompt template was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @prompt_template.update(prompt_template_params)
      redirect_to prompt_template_path(@prompt_template), notice: 'Prompt template was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @prompt_template.destroy
    redirect_to prompt_templates_path, notice: 'Prompt template was successfully deleted.'
  end

  def preview
    context = params[:context].present? ? JSON.parse(params[:context]) : {}
    
    begin
      missing_vars = @prompt_template.validate_context(context)
      if missing_vars == true
        @rendered_prompt = @prompt_template.render_with_context(context)
        @validation_errors = nil
      else
        @rendered_prompt = @prompt_template.preview_with_sample_context
        @validation_errors = missing_vars
      end
    rescue JSON::ParserError
      @validation_errors = ['Invalid JSON in context']
      @rendered_prompt = @prompt_template.preview_with_sample_context
    end

    render json: {
      rendered_prompt: @rendered_prompt,
      validation_errors: @validation_errors,
      variable_names: @prompt_template.variable_names,
      preview_context: context.empty? ? sample_context : context
    }
  end

  def diff
    version_id = params[:version_id]
    
    if version_id && (diff_data = @prompt_template.diff_with_version(version_id))
      render json: diff_data
    else
      render json: { error: 'Version not found' }, status: :not_found
    end
  end

  def publish
    begin
      @prompt_template.publish!
      render json: { 
        message: 'Template published successfully',
        published_version: @prompt_template.version 
      }
    rescue => error
      render json: { error: error.message }, status: :unprocessable_entity
    end
  end

  def create_version
    begin
      new_version = @prompt_template.create_new_version!(version_params)
      render json: {
        message: 'New version created successfully',
        new_version: template_summary(new_version),
        redirect_url: prompt_template_path(new_version)
      }
    rescue => error
      render json: { error: error.message }, status: :unprocessable_entity
    end
  end

  private

  def set_prompt_template
    @prompt_template = current_scope.find(params[:id])
  end

  def set_workspace
    @workspace = current_user.workspaces.find_by(id: params[:workspace_id]) if current_user.respond_to?(:workspaces)
  end

  def current_scope
    @workspace ? @workspace.prompt_templates : PromptTemplate.where(workspace: nil)
  end

  def prompt_template_params
    params.require(:prompt_template).permit(:name, :description, :prompt_body, :output_format, :active, tags: [])
  end

  def version_params
    params.permit(:name, :description, :prompt_body, :output_format, tags: [])
  end

  def template_summary(template)
    {
      id: template.id,
      name: template.name,
      slug: template.slug,
      description: template.description,
      output_format: template.output_format,
      tags: template.tags,
      version: template.version,
      published: template.published,
      active: template.active,
      variable_names: template.variable_names,
      created_at: template.created_at,
      updated_at: template.updated_at,
      is_latest: template.latest_version?
    }
  end

  def template_detail(template)
    template_summary(template).merge(
      prompt_body: template.prompt_body,
      execution_count: template.prompt_executions.count,
      version_count: template.versions.count,
      recent_executions: template.prompt_executions.recent.limit(5).map do |execution|
        {
          id: execution.id,
          status: execution.status,
          created_at: execution.created_at,
          duration: execution.duration
        }
      end
    )
  end

  def sample_context
    @prompt_template.variable_names.map { |var| [var, "[sample_#{var}]"] }.to_h
  end
end