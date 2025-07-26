# frozen_string_literal: true

# Synth Admin module installer for the Rails SaaS starter template.
# This install script sets up a comprehensive admin panel with impersonation,
# audit logs, Sidekiq UI, and feature flag management.

say_status :synth_admin, "Installing Admin Panel module"

# Add admin-specific gems to the application's Gemfile
gem 'flipper', '~> 1.3'
gem 'flipper-ui', '~> 1.3' 
gem 'flipper-active_record', '~> 1.3'
gem 'paper_trail', '~> 15.0'
gem 'pundit', '~> 2.4'

# Run bundle install and set up admin configuration after gems are installed
after_bundle do
  
  # ==========================================
  # CONFIGURATION AND INITIALIZERS
  # ==========================================
  
  # Create admin configuration initializer
  initializer 'admin.rb', <<~'RUBY'
    # Admin panel configuration
    Rails.application.config.admin = ActiveSupport::OrderedOptions.new
    
    # Session timeout for impersonation (in minutes)
    Rails.application.config.admin.impersonation_timeout = 60
    
    # Enable/disable audit logging
    Rails.application.config.admin.audit_enabled = true
    
    # Models to audit (add more as needed)
    Rails.application.config.admin.audited_models = %w[User]
  RUBY

  # Create Flipper configuration
  initializer 'flipper.rb', <<~'RUBY'
    # Flipper feature flag configuration
    require 'flipper'
    require 'flipper/adapters/active_record'
    
    Flipper.configure do |config|
      config.adapter { Flipper::Adapters::ActiveRecord.new }
    end
    
    # Default feature flags
    Rails.application.config.after_initialize do
      Flipper.enable_percentage_of_time(:new_ui, 0)
      Flipper.enable_percentage_of_time(:beta_features, 0)
    end
  RUBY

  # Configure PaperTrail for audit logging
  initializer 'paper_trail.rb', <<~'RUBY'
    # PaperTrail configuration for audit logging
    PaperTrail.config.enabled = Rails.application.config.admin.audit_enabled
    
    # Track additional metadata
    PaperTrail.serializer = PaperTrail::Serializers::JSON
  RUBY

  # ==========================================
  # GENERATORS AND MIGRATIONS  
  # ==========================================

  # Generate PaperTrail configuration
  generate 'paper_trail:install'
  
  # Generate Pundit configuration
  generate 'pundit:install'

  # Generate Flipper migrations
  generate 'flipper:active_record'

  # ==========================================
  # MODELS
  # ==========================================

  # Create Admin User concern
  create_file 'app/models/concerns/admin_user.rb', <<~'RUBY'
    # frozen_string_literal: true

    module AdminUser
      extend ActiveSupport::Concern

      included do
        # Add admin field to users
        # Migration should add: add_column :users, :admin, :boolean, default: false
      end

      def admin?
        admin == true
      end

      def can_impersonate?
        admin? && !being_impersonated?
      end

      def being_impersonated?
        false # Override in impersonation implementation
      end
    end
  RUBY

  # Create Auditable concern for models
  create_file 'app/models/concerns/auditable.rb', <<~'RUBY'
    # frozen_string_literal: true

    module Auditable
      extend ActiveSupport::Concern

      included do
        has_paper_trail(
          meta: {
            ip: :current_ip,
            user_agent: :current_user_agent,
            admin_user_id: :current_admin_user_id
          }
        )
      end

      private

      def current_ip
        RequestStore.store[:current_ip]
      end

      def current_user_agent
        RequestStore.store[:current_user_agent]
      end

      def current_admin_user_id
        RequestStore.store[:current_admin_user_id]
      end
    end
  RUBY

  # Create AuditLog model for easier querying
  create_file 'app/models/audit_log.rb', <<~'RUBY'
    # frozen_string_literal: true

    class AuditLog < ApplicationRecord
      self.table_name = 'versions'

      belongs_to :item, polymorphic: true, optional: true
      belongs_to :admin_user, class_name: 'User', foreign_key: 'whodunnit', optional: true

      scope :recent, -> { order(created_at: :desc) }
      scope :for_item_type, ->(type) { where(item_type: type) }
      scope :for_admin, ->(admin_id) { where(whodunnit: admin_id) }
      scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }

      def item_display_name
        return 'Deleted Item' if item.nil?
        
        item.try(:name) || item.try(:title) || item.try(:email) || "#{item_type} ##{item_id}"
      end

      def action_display
        event.humanize
      end

      def changes_summary
        return 'Item created' if event == 'create'
        return 'Item deleted' if event == 'destroy'
        
        if object_changes.present?
          changed_fields = JSON.parse(object_changes).keys
          "Changed: #{changed_fields.join(', ')}"
        else
          'Updated'
        end
      end
    end
  RUBY

  # ==========================================
  # CONTROLLERS
  # ==========================================

  # Create base admin controller
  create_file 'app/controllers/admin/base_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::BaseController < ApplicationController
      include Pundit::Authorization
      
      before_action :authenticate_user!
      before_action :ensure_admin!
      before_action :set_paper_trail_whodunnit
      before_action :store_request_metadata

      layout 'admin'

      private

      def ensure_admin!
        redirect_to root_path, alert: 'Access denied.' unless current_user&.admin?
      end

      def set_paper_trail_whodunnit
        set_paper_trail_whodunnit(current_user)
      end

      def store_request_metadata
        RequestStore.store[:current_ip] = request.remote_ip
        RequestStore.store[:current_user_agent] = request.user_agent
        RequestStore.store[:current_admin_user_id] = current_user&.id
      end
    end
  RUBY

  # Create admin dashboard controller
  create_file 'app/controllers/admin/dashboard_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::DashboardController < Admin::BaseController
      def index
        @user_count = User.count
        @recent_audit_logs = AuditLog.recent.limit(10)
        @active_feature_flags = Flipper.features.select(&:enabled?)
      end
    end
  RUBY

  # Create users management controller
  create_file 'app/controllers/admin/users_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::UsersController < Admin::BaseController
      before_action :set_user, only: [:show, :edit, :update, :destroy, :impersonate]

      def index
        @users = User.all.order(:email)
        @users = @users.where('email ILIKE ?', "%#{params[:search]}%") if params[:search].present?
        @users = @users.page(params[:page])
      end

      def show
        @audit_logs = AuditLog.for_item_type('User').where(item_id: @user.id).recent.limit(20)
      end

      def edit
      end

      def update
        if @user.update(user_params)
          redirect_to admin_user_path(@user), notice: 'User updated successfully.'
        else
          render :edit
        end
      end

      def destroy
        @user.destroy
        redirect_to admin_users_path, notice: 'User deleted successfully.'
      end

      def impersonate
        if current_user.can_impersonate?
          session[:impersonated_user_id] = @user.id
          session[:admin_user_id] = current_user.id
          session[:impersonation_started_at] = Time.current
          
          redirect_to root_path, notice: "Now impersonating #{@user.email}"
        else
          redirect_to admin_users_path, alert: 'Cannot impersonate user.'
        end
      end

      def stop_impersonation
        if session[:impersonated_user_id]
          session.delete(:impersonated_user_id)
          session.delete(:admin_user_id)
          session.delete(:impersonation_started_at)
          
          redirect_to admin_dashboard_path, notice: 'Stopped impersonating user.'
        else
          redirect_to admin_dashboard_path, alert: 'Not currently impersonating.'
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:email, :admin)
      end
    end
  RUBY

  # Create audit logs controller
  create_file 'app/controllers/admin/audit_logs_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::AuditLogsController < Admin::BaseController
      def index
        @audit_logs = AuditLog.recent
        
        # Apply filters
        @audit_logs = @audit_logs.for_item_type(params[:item_type]) if params[:item_type].present?
        @audit_logs = @audit_logs.for_admin(params[:admin_id]) if params[:admin_id].present?
        
        if params[:start_date].present? && params[:end_date].present?
          @audit_logs = @audit_logs.created_between(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end
        
        @audit_logs = @audit_logs.page(params[:page])
        
        # For filter dropdowns
        @item_types = AuditLog.distinct.pluck(:item_type).compact
        @admin_users = User.where(admin: true)
      end

      def show
        @audit_log = AuditLog.find(params[:id])
      end
    end
  RUBY

  # Create feature flags controller
  create_file 'app/controllers/admin/feature_flags_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::FeatureFlagsController < Admin::BaseController
      def index
        @feature_flags = Flipper.features.to_a
      end

      def show
        @feature_flag = Flipper[params[:id]]
      end

      def toggle
        feature_flag = Flipper[params[:id]]
        
        if feature_flag.enabled?
          feature_flag.disable
          message = "Feature '#{params[:id]}' disabled"
        else
          feature_flag.enable
          message = "Feature '#{params[:id]}' enabled"
        end
        
        redirect_to admin_feature_flags_path, notice: message
      end

      def update_percentage
        feature_flag = Flipper[params[:id]]
        percentage = params[:percentage].to_i
        
        feature_flag.enable_percentage_of_time(percentage)
        
        redirect_to admin_feature_flag_path(params[:id]), 
                    notice: "Feature '#{params[:id]}' set to #{percentage}% of time"
      end
    end
  RUBY

  # Create Sidekiq controller for authentication
  create_file 'app/controllers/admin/sidekiq_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::SidekiqController < Admin::BaseController
      def index
        redirect_to '/admin/sidekiq'
      end
    end
  RUBY

  # ==========================================
  # VIEWS
  # ==========================================

  # Create admin layout
  create_file 'app/views/layouts/admin.html.erb', <<~'ERB'
    <!DOCTYPE html>
    <html>
      <head>
        <title>Admin Panel - <%= Rails.application.class.module_parent_name %></title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        
        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
      </head>

      <body class="admin-panel">
        <!-- Impersonation Banner -->
        <% if session[:impersonated_user_id] %>
          <div class="bg-red-600 text-white p-3 text-center">
            <strong>⚠️ You are impersonating: <%= User.find(session[:impersonated_user_id]).email %></strong>
            <%= link_to "Stop Impersonating", admin_stop_impersonation_path, 
                        method: :delete, 
                        class: "ml-4 underline hover:no-underline",
                        data: { confirm: "Stop impersonating this user?" } %>
          </div>
        <% end %>

        <!-- Admin Navigation -->
        <nav class="bg-gray-800 text-white p-4">
          <div class="container mx-auto flex justify-between items-center">
            <div class="flex space-x-6">
              <%= link_to "Dashboard", admin_dashboard_path, class: "hover:text-gray-300" %>
              <%= link_to "Users", admin_users_path, class: "hover:text-gray-300" %>
              <%= link_to "Audit Logs", admin_audit_logs_path, class: "hover:text-gray-300" %>
              <%= link_to "Feature Flags", admin_feature_flags_path, class: "hover:text-gray-300" %>
              <%= link_to "Sidekiq", "/admin/sidekiq", class: "hover:text-gray-300", target: "_blank" %>
            </div>
            <div class="flex items-center space-x-4">
              <span class="text-sm">Admin: <%= current_user.email %></span>
              <%= link_to "← Back to Site", root_path, class: "hover:text-gray-300" %>
              <%= link_to "Logout", destroy_user_session_path, method: :delete, class: "hover:text-gray-300" %>
            </div>
          </div>
        </nav>

        <!-- Flash Messages -->
        <% if notice %>
          <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 mx-4 mt-4 rounded">
            <%= notice %>
          </div>
        <% end %>

        <% if alert %>
          <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 mx-4 mt-4 rounded">
            <%= alert %>
          </div>
        <% end %>

        <!-- Main Content -->
        <main class="container mx-auto px-4 py-8">
          <%= yield %>
        </main>
      </body>
    </html>
  ERB

  # Create dashboard view
  create_file 'app/views/admin/dashboard/index.html.erb', <<~'ERB'
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">Admin Dashboard</h1>
      <p class="text-gray-600">Manage users, monitor system activity, and control feature flags.</p>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="text-2xl font-bold text-blue-600"><%= @user_count %></div>
          <div class="ml-3">
            <p class="text-sm font-medium text-gray-500">Total Users</p>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="text-2xl font-bold text-green-600"><%= @active_feature_flags.count %></div>
          <div class="ml-3">
            <p class="text-sm font-medium text-gray-500">Active Feature Flags</p>
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-lg shadow p-6">
        <div class="flex items-center">
          <div class="text-2xl font-bold text-purple-600"><%= @recent_audit_logs.count %></div>
          <div class="ml-3">
            <p class="text-sm font-medium text-gray-500">Recent Actions</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      <!-- Recent Audit Logs -->
      <div class="bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Recent Activity</h3>
        </div>
        <div class="p-6">
          <% if @recent_audit_logs.any? %>
            <div class="space-y-3">
              <% @recent_audit_logs.each do |log| %>
                <div class="flex justify-between items-center py-2 border-b border-gray-100 last:border-0">
                  <div>
                    <p class="text-sm font-medium"><%= log.action_display %> <%= log.item_display_name %></p>
                    <p class="text-xs text-gray-500"><%= time_ago_in_words(log.created_at) %> ago</p>
                  </div>
                  <%= link_to "View", admin_audit_log_path(log), class: "text-blue-600 hover:text-blue-800 text-sm" %>
                </div>
              <% end %>
            </div>
            <div class="mt-4">
              <%= link_to "View All Logs →", admin_audit_logs_path, class: "text-blue-600 hover:text-blue-800 text-sm" %>
            </div>
          <% else %>
            <p class="text-gray-500 text-sm">No recent activity</p>
          <% end %>
        </div>
      </div>

      <!-- Quick Links -->
      <div class="bg-white rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Quick Actions</h3>
        </div>
        <div class="p-6">
          <div class="space-y-3">
            <%= link_to admin_users_path, class: "block p-3 border border-gray-200 rounded hover:bg-gray-50" do %>
              <p class="font-medium">Manage Users</p>
              <p class="text-sm text-gray-600">View, edit, and impersonate users</p>
            <% end %>
            
            <%= link_to admin_feature_flags_path, class: "block p-3 border border-gray-200 rounded hover:bg-gray-50" do %>
              <p class="font-medium">Feature Flags</p>
              <p class="text-sm text-gray-600">Toggle experimental features</p>
            <% end %>
            
            <%= link_to "/admin/sidekiq", target: "_blank", class: "block p-3 border border-gray-200 rounded hover:bg-gray-50" do %>
              <p class="font-medium">Sidekiq Dashboard</p>
              <p class="text-sm text-gray-600">Monitor background jobs</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
  ERB

  # ==========================================
  # ROUTES
  # ==========================================

  # Add admin routes
  route <<~'RUBY'
    namespace :admin do
      root 'dashboard#index'
      get 'dashboard', to: 'dashboard#index'
      
      resources :users do
        member do
          post :impersonate
        end
      end
      
      delete 'stop_impersonation', to: 'users#stop_impersonation'
      
      resources :audit_logs, only: [:index, :show]
      
      resources :feature_flags, only: [:index, :show] do
        member do
          patch :toggle
          patch :update_percentage
        end
      end
    end
  RUBY

  # Mount Sidekiq Web UI for admins
  route <<~'RUBY'
    require 'sidekiq/web'
    
    # Secure Sidekiq Web UI
    Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
      # In production, use environment variables for credentials
      [user, password] == ['admin', Rails.application.credentials.dig(:sidekiq, :password) || 'changeme']
    end
    
    mount Sidekiq::Web => '/admin/sidekiq'
  RUBY

  # Mount Flipper UI for feature flag management
  route <<~'RUBY'
    require 'flipper/ui'
    
    # Secure Flipper UI (only accessible to admins)
    flipper_app = Rack::Builder.new do
      use Rack::Auth::Basic do |user, password|
        [user, password] == ['admin', Rails.application.credentials.dig(:flipper, :password) || 'changeme']
      end
      run Flipper::UI.app
    end
    
    mount flipper_app => '/admin/flipper'
  RUBY

  # ==========================================
  # MIGRATIONS
  # ==========================================

  # Create admin migration for users
  create_file 'db/migrate/001_add_admin_to_users.rb', <<~'RUBY'
    class AddAdminToUsers < ActiveRecord::Migration[7.1]
      def change
        add_column :users, :admin, :boolean, default: false, null: false
        add_index :users, :admin
      end
    end
  RUBY

  # ==========================================
  # TESTS
  # ==========================================

  # Create admin controller tests
  create_file 'test/controllers/admin/dashboard_controller_test.rb', <<~'RUBY'
    require 'test_helper'

    class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
      def setup
        @admin_user = users(:admin_user)
        @regular_user = users(:regular_user)
      end

      test 'admin can access dashboard' do
        sign_in @admin_user
        get admin_dashboard_path
        assert_response :success
      end

      test 'regular user cannot access dashboard' do
        sign_in @regular_user
        get admin_dashboard_path
        assert_redirected_to root_path
      end

      test 'guest cannot access dashboard' do
        get admin_dashboard_path
        assert_redirected_to new_user_session_path
      end
    end
  RUBY

  # Create fixtures for testing
  create_file 'test/fixtures/users.yml', <<~'YAML'
    admin_user:
      email: admin@example.com
      admin: true
      
    regular_user:
      email: user@example.com
      admin: false
  YAML

  # ==========================================
  # FINAL SETUP
  # ==========================================

  # Add RequestStore gem for tracking request metadata
  gem 'request_store'

  # Add kaminari for pagination
  gem 'kaminari'

  say_status :synth_admin, "Admin panel installed successfully!"
  say_status :synth_admin, "Next steps:"
  say_status :synth_admin, "1. Run: rails db:migrate"
  say_status :synth_admin, "2. Create an admin user: User.create!(email: 'admin@example.com', password: 'password', admin: true)"
  say_status :synth_admin, "3. Visit /admin to access the admin panel"
  say_status :synth_admin, "4. Configure Sidekiq and Flipper credentials in Rails credentials"
end