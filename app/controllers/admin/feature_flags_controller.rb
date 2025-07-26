# frozen_string_literal: true

class Admin::FeatureFlagsController < Admin::BaseController
  def index
    @feature_flags = FeatureFlag.all.order(:name)
    @workspaces = Workspace.all.order(:name) if defined?(Workspace)
  end

  def show
    @feature_flag = FeatureFlag.find(params[:id])
    @workspaces = Workspace.all.order(:name) if defined?(Workspace)
  end

  def new
    @feature_flag = FeatureFlag.new
  end

  def edit
    @feature_flag = FeatureFlag.find(params[:id])
  end

  def create
    @feature_flag = FeatureFlag.new(feature_flag_params)
    
    if @feature_flag.save
      AuditLog.create_log(
        user: current_user,
        action: 'create',
        resource_type: 'FeatureFlag',
        resource_id: @feature_flag.id,
        description: "Created feature flag: #{@feature_flag.name}",
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_feature_flags_path, notice: 'Feature flag created successfully.'
    else
      render :new
    end
  end

  def update
    @feature_flag = FeatureFlag.find(params[:id])
    old_enabled = @feature_flag.enabled
    
    if @feature_flag.update(feature_flag_params)
      action = old_enabled != @feature_flag.enabled ? 'toggle' : 'update'
      
      AuditLog.create_log(
        user: current_user,
        action: action,
        resource_type: 'FeatureFlag',
        resource_id: @feature_flag.id,
        description: "#{action.humanize}d feature flag: #{@feature_flag.name}",
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_feature_flag_path(@feature_flag), notice: 'Feature flag updated successfully.'
    else
      render :edit
    end
  end

  def toggle
    @feature_flag = FeatureFlag.find(params[:id])
    @feature_flag.update!(enabled: !@feature_flag.enabled)
    
    AuditLog.create_log(
      user: current_user,
      action: 'toggle',
      resource_type: 'FeatureFlag',
      resource_id: @feature_flag.id,
      description: "#{@feature_flag.enabled? ? 'Enabled' : 'Disabled'} feature flag: #{@feature_flag.name}",
      ip_address: @current_ip,
      user_agent: @current_user_agent
    )
    
    redirect_to admin_feature_flags_path, notice: "Feature flag #{@feature_flag.enabled? ? 'enabled' : 'disabled'}."
  end

  def toggle_workspace
    @feature_flag = FeatureFlag.find(params[:id])
    @workspace = Workspace.find(params[:workspace_id]) if defined?(Workspace)
    
    if @workspace && @feature_flag
      workspace_flag = @feature_flag.workspace_feature_flags.find_or_initialize_by(workspace: @workspace)
      workspace_flag.enabled = !workspace_flag.enabled
      workspace_flag.save!
      
      AuditLog.create_log(
        user: current_user,
        action: 'toggle_workspace',
        resource_type: 'FeatureFlag',
        resource_id: @feature_flag.id,
        description: "#{workspace_flag.enabled? ? 'Enabled' : 'Disabled'} feature flag: #{@feature_flag.name} for workspace: #{@workspace.name}",
        metadata: { workspace_id: @workspace.id, workspace_name: @workspace.name },
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_feature_flag_path(@feature_flag), notice: "Feature flag #{workspace_flag.enabled? ? 'enabled' : 'disabled'} for workspace."
    else
      redirect_to admin_feature_flags_path, alert: 'Feature flag or workspace not found.'
    end
  end

  private

  def feature_flag_params
    params.require(:feature_flag).permit(:name, :description, :enabled)
  end
end