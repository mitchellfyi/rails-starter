# frozen_string_literal: true

class Admin::McpFetchersController < Admin::BaseController
  def index
    @mcp_fetchers = McpFetcher.all.order(:name)
    @workspaces = Workspace.all.order(:name) if defined?(Workspace)
  end

  def show
    @mcp_fetcher = McpFetcher.find(params[:id])
    @workspaces = Workspace.all.order(:name) if defined?(Workspace)
  end

  def new
    @mcp_fetcher = McpFetcher.new
  end

  def edit
    @mcp_fetcher = McpFetcher.find(params[:id])
  end

  def create
    @mcp_fetcher = McpFetcher.new(mcp_fetcher_params)
    
    if @mcp_fetcher.save
      AuditLog.create_log(
        user: current_user,
        action: 'create',
        resource_type: 'McpFetcher',
        resource_id: @mcp_fetcher.id,
        description: "Created MCP fetcher: #{@mcp_fetcher.name}",
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_mcp_fetchers_path, notice: 'MCP fetcher created successfully.'
    else
      render :new
    end
  end

  def update
    @mcp_fetcher = McpFetcher.find(params[:id])
    old_enabled = @mcp_fetcher.enabled
    
    if @mcp_fetcher.update(mcp_fetcher_params)
      action = old_enabled != @mcp_fetcher.enabled ? 'toggle' : 'update'
      
      AuditLog.create_log(
        user: current_user,
        action: action,
        resource_type: 'McpFetcher',
        resource_id: @mcp_fetcher.id,
        description: "#{action.humanize}d MCP fetcher: #{@mcp_fetcher.name}",
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_mcp_fetcher_path(@mcp_fetcher), notice: 'MCP fetcher updated successfully.'
    else
      render :edit
    end
  end

  def toggle
    @mcp_fetcher = McpFetcher.find(params[:id])
    @mcp_fetcher.update!(enabled: !@mcp_fetcher.enabled)
    
    AuditLog.create_log(
      user: current_user,
      action: 'toggle',
      resource_type: 'McpFetcher',
      resource_id: @mcp_fetcher.id,
      description: "#{@mcp_fetcher.enabled? ? 'Enabled' : 'Disabled'} MCP fetcher: #{@mcp_fetcher.name}",
      ip_address: @current_ip,
      user_agent: @current_user_agent
    )
    
    redirect_to admin_mcp_fetchers_path, notice: "MCP fetcher #{@mcp_fetcher.enabled? ? 'enabled' : 'disabled'}."
  end

  def toggle_workspace
    @mcp_fetcher = McpFetcher.find(params[:id])
    @workspace = Workspace.find(params[:workspace_id]) if defined?(Workspace)
    
    if @workspace && @mcp_fetcher
      workspace_fetcher = @mcp_fetcher.workspace_mcp_fetchers.find_or_initialize_by(workspace: @workspace)
      workspace_fetcher.enabled = !workspace_fetcher.enabled
      workspace_fetcher.save!
      
      AuditLog.create_log(
        user: current_user,
        action: 'toggle_workspace',
        resource_type: 'McpFetcher',
        resource_id: @mcp_fetcher.id,
        description: "#{workspace_fetcher.enabled? ? 'Enabled' : 'Disabled'} MCP fetcher: #{@mcp_fetcher.name} for workspace: #{@workspace.name}",
        metadata: { workspace_id: @workspace.id, workspace_name: @workspace.name },
        ip_address: @current_ip,
        user_agent: @current_user_agent
      )
      
      redirect_to admin_mcp_fetcher_path(@mcp_fetcher), notice: "MCP fetcher #{workspace_fetcher.enabled? ? 'enabled' : 'disabled'} for workspace."
    else
      redirect_to admin_mcp_fetchers_path, alert: 'MCP fetcher or workspace not found.'
    end
  end

  def destroy
    @mcp_fetcher = McpFetcher.find(params[:id])
    fetcher_name = @mcp_fetcher.name
    
    @mcp_fetcher.destroy
    
    AuditLog.create_log(
      user: current_user,
      action: 'delete',
      resource_type: 'McpFetcher',
      resource_id: nil,
      description: "Deleted MCP fetcher: #{fetcher_name}",
      ip_address: @current_ip,
      user_agent: @current_user_agent
    )
    
    redirect_to admin_mcp_fetchers_path, notice: 'MCP fetcher deleted successfully.'
  end

  private

  def mcp_fetcher_params
    params.require(:mcp_fetcher).permit(:name, :description, :provider_type, :enabled, :sample_output, 
                                        parameters: {}, configuration: {}).tap do |permitted|
      # Parse JSON strings for configuration and parameters
      if permitted[:configuration].is_a?(String) && permitted[:configuration].present?
        begin
          permitted[:configuration] = JSON.parse(permitted[:configuration])
        rescue JSON::ParserError
          # Leave as string if invalid JSON - validation will catch this
        end
      end
      
      if permitted[:parameters].is_a?(String) && permitted[:parameters].present?
        begin
          permitted[:parameters] = JSON.parse(permitted[:parameters])
        rescue JSON::ParserError
          # Leave as string if invalid JSON - validation will catch this
        end
      end
    end
  end
end