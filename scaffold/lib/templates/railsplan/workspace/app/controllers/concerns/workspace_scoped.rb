# frozen_string_literal: true

module WorkspaceScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_workspace, if: :workspace_param_present?
    before_action :ensure_workspace_access, if: :workspace_param_present?
  end

  private

  def set_current_workspace
    @current_workspace = Workspace.find_by!(slug: params[:workspace_slug] || params[:slug])
  end

  def ensure_workspace_access
    authorize @current_workspace if defined?(@current_workspace)
  end

  def workspace_param_present?
    params[:workspace_slug].present? || (params[:slug].present? && controller_name == 'workspaces')
  end

  def current_workspace
    @current_workspace
  end
  helper_method :current_workspace
end