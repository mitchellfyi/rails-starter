# frozen_string_literal: true

# Workspace switcher component for multi-tenant navigation
class WorkspaceSwitcherComponent < ApplicationComponent
  def initialize(current_user:, current_workspace: nil, **html_options)
    @current_user = current_user
    @current_workspace = current_workspace
    @html_options = html_options
  end

  private

  attr_reader :current_user, :current_workspace, :html_options

  def workspaces
    @workspaces ||= current_user.workspaces.includes(:workspace_memberships).order(:name)
  end

  def has_multiple_workspaces?
    workspaces.count > 1
  end

  def current_workspace_name
    current_workspace&.name || 'Select Workspace'
  end

  def switcher_classes
    'relative inline-block text-left'
  end

  def trigger_classes
    'inline-flex w-full justify-center items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2'
  end

  def workspace_item_classes(workspace)
    base_classes = 'flex items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900'
    base_classes += ' bg-blue-50 text-blue-900' if workspace == current_workspace
    base_classes
  end

  def workspace_initial(workspace)
    workspace.name.first.upcase
  end

  def workspace_url(workspace)
    # This would depend on your routing setup
    # For subdomain routing: "http://#{workspace.slug}.#{request.domain}"
    # For path routing: workspace_path(workspace)
    workspace_path(workspace)
  end

  def chevron_svg
    '<svg class="ml-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
    </svg>'.html_safe
  end
end