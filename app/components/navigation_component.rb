# frozen_string_literal: true

# Navigation bar component that integrates all the UI components
class NavigationComponent < ApplicationComponent
  def initialize(
    current_user:,
    current_workspace: nil,
    show_workspace_switcher: true,
    show_notifications: true,
    **html_options
  )
    @current_user = current_user
    @current_workspace = current_workspace
    @show_workspace_switcher = show_workspace_switcher
    @show_notifications = show_notifications
    @html_options = html_options
  end

  private

  attr_reader :current_user, :current_workspace, :show_workspace_switcher, :show_notifications, :html_options

  def navigation_classes
    'bg-white shadow-sm border-b border-gray-200'
  end

  def container_classes
    'max-w-7xl mx-auto px-4 sm:px-6 lg:px-8'
  end

  def nav_content_classes
    'flex justify-between items-center h-16'
  end

  def logo_classes
    'flex items-center space-x-3'
  end

  def nav_links_classes
    'hidden md:flex items-center space-x-8'
  end

  def mobile_nav_classes
    'md:hidden'
  end

  def user_menu_classes
    'flex items-center space-x-4'
  end

  def nav_links
    [
      { name: 'Dashboard', path: root_path, icon: 'home' },
      { name: 'Workspaces', path: workspaces_path, icon: 'office-building' },
      { name: 'Settings', path: settings_path, icon: 'cog' }
    ]
  end

  def user_dropdown_items
    items = [
      { name: 'Profile', path: profile_path, icon: 'user' },
      { name: 'Account Settings', path: account_settings_path, icon: 'cog' },
      { name: 'Billing', path: billing_path, icon: 'credit-card' }
    ]
    
    if current_user.admin?
      items << { divider: true }
      items << { name: 'Admin Panel', path: admin_root_path, icon: 'shield-check' }
    end
    
    items << { divider: true }
    items << { name: 'Sign Out', path: destroy_user_session_path, icon: 'logout', method: :delete }
    
    items
  end

  def app_name
    Rails.application.class.module_parent_name
  end

  def app_logo_url
    asset_path('logo.svg')
  rescue
    nil
  end

  def current_page?(path)
    request.path == path
  end

  def nav_link_classes(path)
    base_classes = 'text-sm font-medium transition-colors duration-200'
    if current_page?(path)
      "#{base_classes} text-blue-600 border-b-2 border-blue-600"
    else
      "#{base_classes} text-gray-500 hover:text-gray-900"
    end
  end

  def mobile_menu_button_classes
    'md:hidden inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500'
  end
end