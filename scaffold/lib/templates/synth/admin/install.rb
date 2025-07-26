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
gem 'request_store' # Moved from end of file
gem 'kaminari' # Moved from end of file

# Run bundle install and set up admin configuration after gems are installed
after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/domains/admin/app/{controllers/admin,policies,views/admin/dashboard,views/admin/users,views/admin/audit_logs,views/admin/feature_flags,views/layouts}'
  run 'mkdir -p app/models/concerns' # Ensure models directory exists

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
        has_many :user_activities, dependent: :destroy
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

  # Create ActivityTrackable concern for models to automatically log activities
  create_file 'app/models/concerns/activity_trackable.rb', <<~'RUBY'
    # frozen_string_literal: true

    module ActivityTrackable
      extend ActiveSupport::Concern

      included do
        after_create :log_create_activity
        after_update :log_update_activity
        after_destroy :log_destroy_activity
      end

      private

      def log_create_activity
        return unless should_log_activity?
        
        UserActivity.log_user_activity(
          user: activity_user,
          action: 'create',
          description: create_activity_description,
          resource: self,
          workspace: activity_workspace
        )
      end

      def log_update_activity
        return unless should_log_activity?
        return unless saved_changes.any?
        
        UserActivity.log_user_activity(
          user: activity_user,
          action: 'update',
          description: update_activity_description,
          resource: self,
          workspace: activity_workspace,
          metadata: { changes: saved_changes }
        )
      end

      def log_destroy_activity
        return unless should_log_activity?
        
        UserActivity.log_user_activity(
          user: activity_user,
          action: 'destroy',
          description: destroy_activity_description,
          resource: nil,
          workspace: activity_workspace,
          metadata: { destroyed_resource_id: id, destroyed_resource_type: self.class.name }
        )
      end

      def should_log_activity?
        activity_user.present?
      end

      def activity_user
        # Override in models to specify which user performed the action
        # Default to current user from PaperTrail
        PaperTrail.request.whodunnit && User.find_by(id: PaperTrail.request.whodunnit)
      end

      def activity_workspace
        # Override in models to specify the associated workspace
        respond_to?(:workspace) ? workspace : nil
      end

      def create_activity_description
        "Created #{self.class.name.humanize.downcase}"
      end

      def update_activity_description
        "Updated #{self.class.name.humanize.downcase}"
      end

      def destroy_activity_description
        "Deleted #{self.class.name.humanize.downcase}"
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
      scope :for_workspace, ->(workspace_id) { joins(:item).where(item: { workspace_id: workspace_id }) }
      scope :by_event_type, ->(event_type) { where(event: event_type) }

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

      def self.log_action(user:, action:, resource:, ip_address: nil, changes: nil)
        create!(
          event: action,
          item: resource,
          whodunnit: user&.id,
          object_changes: changes&.to_json,
          created_at: Time.current
        )
      end

      def formatted_changes
        return 'No changes recorded' unless object_changes.present?
        
        changes = JSON.parse(object_changes)
        changes.map do |field, (old_val, new_val)|
          "#{field.humanize}: '#{old_val}' → '#{new_val}'"
        end.join(', ')
      end

      def resource
        item
      end
    end
  RUBY

  # Create UserActivity model for user activity feeds
  create_file 'app/models/user_activity.rb', <<~'RUBY'
    # frozen_string_literal: true

    class UserActivity < ApplicationRecord
      belongs_to :user
      belongs_to :workspace, optional: true
      belongs_to :resource, polymorphic: true, optional: true

      scope :recent, -> { order(created_at: :desc) }
      scope :for_workspace, ->(workspace_id) { where(workspace_id: workspace_id) }
      scope :by_action, ->(action) { where(action: action) }
      scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
      scope :by_resource_type, ->(type) { where(resource_type: type) }

      validates :action, presence: true
      validates :description, presence: true

      # Common activity types
      ACTIVITY_TYPES = %w[
        create update destroy
        invitation_sent invitation_accepted invitation_declined
        subscription_created subscription_updated subscription_cancelled
        blog_post_created blog_post_published blog_post_unpublished
        login logout
        profile_updated
        workspace_created workspace_updated workspace_joined workspace_left
      ].freeze

      validates :action, inclusion: { in: ACTIVITY_TYPES }

      def self.log_user_activity(user:, action:, description:, resource: nil, workspace: nil, metadata: {})
        create!(
          user: user,
          action: action,
          description: description,
          resource: resource,
          workspace: workspace,
          metadata: metadata,
          ip_address: RequestStore.store[:current_ip],
          user_agent: RequestStore.store[:current_user_agent]
        )
      end

      def icon_class
        case action
        when 'create', 'workspace_created', 'blog_post_created', 'subscription_created'
          'plus-circle'
        when 'update', 'workspace_updated', 'profile_updated', 'subscription_updated'
          'pencil'
        when 'destroy', 'subscription_cancelled'
          'trash'
        when 'invitation_sent'
          'mail'
        when 'invitation_accepted', 'workspace_joined'
          'user-plus'
        when 'invitation_declined', 'workspace_left'
          'user-minus'
        when 'login'
          'log-in'
        when 'logout'
          'log-out'
        when 'blog_post_published'
          'eye'
        when 'blog_post_unpublished'
          'eye-off'
        else
          'activity'
        end
      end

      def display_color
        case action
        when 'create', 'workspace_created', 'blog_post_created', 'invitation_accepted', 'workspace_joined'
          'green'
        when 'update', 'workspace_updated', 'profile_updated', 'subscription_updated'
          'blue'
        when 'destroy', 'subscription_cancelled', 'invitation_declined', 'workspace_left'
          'red'
        when 'invitation_sent', 'blog_post_published', 'login'
          'purple'
        else
          'gray'
        end
      end
    end
  RUBY

  # ==========================================
  # CONTROLLERS
  # ==========================================

  # Create base admin controller
  create_file 'app/domains/admin/app/controllers/admin/base_controller.rb', <<~'RUBY'
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
  create_file 'app/domains/admin/app/controllers/admin/dashboard_controller.rb', <<~'RUBY'
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
  create_file 'app/domains/admin/app/controllers/admin/users_controller.rb', <<~'RUBY'
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
  create_file 'app/domains/admin/app/controllers/admin/audit_logs_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'csv'

    class Admin::AuditLogsController < Admin::BaseController
      def index
        @audit_logs = AuditLog.recent
        
        # Apply filters
        @audit_logs = @audit_logs.for_item_type(params[:item_type]) if params[:item_type].present?
        @audit_logs = @audit_logs.for_admin(params[:admin_id]) if params[:admin_id].present?
        @audit_logs = @audit_logs.by_event_type(params[:event_type]) if params[:event_type].present?
        @audit_logs = @audit_logs.for_workspace(params[:workspace_id]) if params[:workspace_id].present?
        
        if params[:start_date].present? && params[:end_date].present?
          @audit_logs = @audit_logs.created_between(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end
        
        # Search functionality
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @audit_logs = @audit_logs.joins(:item).where(
            "item_type ILIKE ? OR object_changes ILIKE ?", 
            search_term, search_term
          )
        end
        
        respond_to do |format|
          format.html do
            @audit_logs = @audit_logs.page(params[:page])
            
            # For filter dropdowns
            @item_types = AuditLog.distinct.pluck(:item_type).compact
            @admin_users = User.where(admin: true)
            @event_types = AuditLog.distinct.pluck(:event).compact
            @workspaces = Workspace.all if defined?(Workspace)
          end
          
          format.csv do
            send_data generate_csv_export(@audit_logs), 
                      filename: "audit_logs_#{Date.current}.csv",
                      type: 'text/csv'
          end
          
          format.json do
            render json: @audit_logs.page(params[:page])
          end
        end
      end

      def show
        @audit_log = AuditLog.find(params[:id])
      end

      def export
        @audit_logs = apply_filters(AuditLog.recent)
        
        respond_to do |format|
          format.csv do
            send_data generate_csv_export(@audit_logs), 
                      filename: "audit_logs_export_#{Date.current}.csv",
                      type: 'text/csv'
          end
        end
      end

      private

      def apply_filters(relation)
        relation = relation.for_item_type(params[:item_type]) if params[:item_type].present?
        relation = relation.for_admin(params[:admin_id]) if params[:admin_id].present?
        relation = relation.by_event_type(params[:event_type]) if params[:event_type].present?
        relation = relation.for_workspace(params[:workspace_id]) if params[:workspace_id].present?
        
        if params[:start_date].present? && params[:end_date].present?
          relation = relation.created_between(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end
        
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          relation = relation.joins(:item).where(
            "item_type ILIKE ? OR object_changes ILIKE ?", 
            search_term, search_term
          )
        end
        
        relation
      end

      def generate_csv_export(audit_logs)
        CSV.generate(headers: true) do |csv|
          csv << ['ID', 'Action', 'Resource Type', 'Resource ID', 'Admin User', 'Changes', 'IP Address', 'Created At']
          
          audit_logs.find_each do |log|
            csv << [
              log.id,
              log.action_display,
              log.item_type,
              log.item_id,
              log.admin_user&.email || 'System',
              log.changes_summary,
              log.object&.dig('ip'),
              log.created_at.strftime('%Y-%m-%d %H:%M:%S')
            ]
          end
        end
      end
    end
  RUBY

  # Create user activity controller for activity feeds
  create_file 'app/domains/admin/app/controllers/admin/user_activities_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::UserActivitiesController < Admin::BaseController
      def index
        @user_activities = UserActivity.recent
        
        # Apply filters
        @user_activities = @user_activities.joins(:user).where(users: { id: params[:user_id] }) if params[:user_id].present?
        @user_activities = @user_activities.for_workspace(params[:workspace_id]) if params[:workspace_id].present?
        @user_activities = @user_activities.by_action(params[:action_type]) if params[:action_type].present?
        @user_activities = @user_activities.by_resource_type(params[:resource_type]) if params[:resource_type].present?
        
        if params[:start_date].present? && params[:end_date].present?
          @user_activities = @user_activities.created_between(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end
        
        @user_activities = @user_activities.page(params[:page])
        
        # For filter dropdowns
        @users = User.all.order(:email)
        @workspaces = Workspace.all if defined?(Workspace)
        @action_types = UserActivity::ACTIVITY_TYPES
        @resource_types = UserActivity.distinct.pluck(:resource_type).compact
      end

      def show
        @user_activity = UserActivity.find(params[:id])
      end
    end
  RUBY

  # Create regular user activity controller (for non-admin users)
  create_file 'app/controllers/activity_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class ActivityController < ApplicationController
      before_action :authenticate_user!

      def index
        @activities = current_user.user_activities.recent
        
        # Apply filters
        @activities = @activities.for_workspace(params[:workspace_id]) if params[:workspace_id].present?
        @activities = @activities.by_action(params[:action_type]) if params[:action_type].present?
        @activities = @activities.by_resource_type(params[:resource_type]) if params[:resource_type].present?
        
        if params[:start_date].present? && params[:end_date].present?
          @activities = @activities.created_between(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end
        
        @activities = @activities.page(params[:page])
        
        # For filter dropdowns 
        @workspaces = current_user.workspaces if current_user.respond_to?(:workspaces)
        @action_types = UserActivity::ACTIVITY_TYPES
        @resource_types = @activities.distinct.pluck(:resource_type).compact
      end

      def show
        @activity = current_user.user_activities.find(params[:id])
      end
    end
  RUBY

  # Create feature flags controller
  create_file 'app/domains/admin/app/controllers/admin/feature_flags_controller.rb', <<~'RUBY'
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
  create_file 'app/domains/admin/app/controllers/admin/sidekiq_controller.rb', <<~'RUBY'
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
  create_file 'app/domains/admin/app/views/layouts/admin.html.erb', <<~'ERB'
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
              <%= link_to "User Activities", admin_user_activities_path, class: "hover:text-gray-300" %>
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
  create_file 'app/domains/admin/app/views/admin/dashboard/index.html.erb', <<~'ERB'
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

  # Create users management views
  create_file 'app/domains/admin/app/views/admin/users/index.html.erb', <<~'ERB'
    <div class="mb-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
        <%= form_with url: admin_users_path, method: :get, local: true, class: "flex" do |f| %>
          <%= f.text_field :search, placeholder: "Search by email...", value: params[:search], 
                          class: "border border-gray-300 rounded-l px-4 py-2" %>
          <%= f.submit "Search", class: "bg-blue-600 text-white px-4 py-2 rounded-r hover:bg-blue-700" %>
        <% end %>
      </div>
    </div>

    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul class="divide-y divide-gray-200">
        <% @users.each do |user| %>
          <li>
            <div class="px-4 py-4 flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                    <%= user.email.first.upcase %>
                  </div>
                </div>
                <div class="ml-4">
                  <div class="text-sm font-medium text-gray-900"><%= user.email %></div>
                  <div class="text-sm text-gray-500">
                    <% if user.admin? %>
                      <span class="bg-red-100 text-red-800 px-2 py-1 text-xs rounded">Admin</span>
                    <% else %>
                      <span class="bg-gray-100 text-gray-800 px-2 py-1 text-xs rounded">Regular User</span>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="flex space-x-2">
                <%= link_to "View", admin_user_path(user), class: "text-blue-600 hover:text-blue-800" %>
                <%= link_to "Edit", edit_admin_user_path(user), class: "text-green-600 hover:text-green-800" %>
                <% if current_user.can_impersonate? && user != current_user %>
                  <%= link_to "Impersonate", admin_user_impersonate_path(user), method: :post,
                             class: "text-purple-600 hover:text-purple-800",
                             data: { confirm: "Impersonate #{user.email}?" } %>
                <% end %>
              </div>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
  ERB

  # Create user show view  
  create_file 'app/domains/admin/app/views/admin/users/show.html.erb', <<~'ERB'
    <div class="mb-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900">User Details</h1>
        <div class="space-x-2">
          <%= link_to "Edit User", edit_admin_user_path(@user), class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
          <% if current_user.can_impersonate? && @user != current_user %>
            <%= link_to "Impersonate", admin_user_impersonate_path(@user), method: :post,
                       class: "bg-purple-600 text-white px-4 py-2 rounded hover:bg-purple-700",
                       data: { confirm: "Impersonate #{@user.email}?" } %>
          <% end %>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      <!-- User Information -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">User Information</h3>
        <dl class="space-y-3">
          <div>
            <dt class="text-sm font-medium text-gray-500">Email</dt>
            <dd class="text-sm text-gray-900"><%= @user.email %></dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Admin Status</dt>
            <dd class="text-sm text-gray-900">
              <% if @user.admin? %>
                <span class="bg-red-100 text-red-800 px-2 py-1 text-xs rounded">Admin</span>
              <% else %>
                <span class="bg-gray-100 text-gray-800 px-2 py-1 text-xs rounded">Regular User</span>
              <% end %>
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Created</dt>
            <dd class="text-sm text-gray-900"><%= @user.created_at.strftime("%B %d, %Y at %I:%M %p") %></dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
            <dd class="text-sm text-gray-900"><%= @user.updated_at.strftime("%B %d, %Y at %I:%M %p") %></dd>
          </div>
        </dl>
      </div>

      <!-- Recent Activity -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h3>
        <% if @audit_logs.any? %>
          <div class="space-y-3">
            <% @audit_logs.each do |log| %>
              <div class="border-b border-gray-200 pb-2 last:border-0">
                <p class="text-sm font-medium"><%= log.action_display %></p>
                <p class="text-xs text-gray-500"><%= time_ago_in_words(log.created_at) %> ago</p>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500 text-sm">No recent activity</p>
        <% end %>
      </div>
    </div>
  ERB

  # Create audit logs index view
  create_file 'app/domains/admin/app/views/admin/audit_logs/index.html.erb', <<~'ERB'
    <div class="mb-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900 mb-4">Audit Logs</h1>
        <div class="flex space-x-2">
          <%= link_to "Export CSV", admin_audit_logs_path(format: :csv, **request.query_parameters), 
                      class: "bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700" %>
          <%= link_to "Export JSON", admin_audit_logs_path(format: :json, **request.query_parameters), 
                      class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
        </div>
      </div>
      
      <!-- Enhanced Filters -->
      <%= form_with url: admin_audit_logs_path, method: :get, local: true, class: "bg-white p-4 rounded-lg shadow mb-6" do |f| %>
        <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
          <div>
            <%= f.label :search, "Search", class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :search, value: params[:search], placeholder: "Search logs...", 
                            class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
          <div>
            <%= f.label :item_type, "Resource Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :item_type, options_for_select([['All Types', '']] + @item_types.map { |t| [t, t] }, params[:item_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <div>
            <%= f.label :event_type, "Event Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :event_type, options_for_select([['All Events', '']] + @event_types.map { |t| [t.humanize, t] }, params[:event_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <div>
            <%= f.label :admin_id, "Admin User", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :admin_id, options_for_select([['All Admins', '']] + @admin_users.map { |u| [u.email, u.id] }, params[:admin_id]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <% if defined?(@workspaces) && @workspaces&.any? %>
          <div>
            <%= f.label :workspace_id, "Workspace", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :workspace_id, options_for_select([['All Workspaces', '']] + @workspaces.map { |w| [w.name, w.id] }, params[:workspace_id]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <% end %>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div>
            <%= f.label :start_date, "Start Date", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :start_date, value: params[:start_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
          <div>
            <%= f.label :end_date, "End Date", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :end_date, value: params[:end_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
        </div>
        <div class="mt-4">
          <%= f.submit "Filter", class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
          <%= link_to "Clear", admin_audit_logs_path, class: "ml-2 bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700" %>
        </div>
      <% end %>
    </div>

    <!-- Results Summary -->
    <div class="mb-4">
      <p class="text-sm text-gray-600">
        Showing <%= @audit_logs.count %> audit logs
        <% if params.any? { |key, value| value.present? && key != 'controller' && key != 'action' } %>
          (filtered)
        <% end %>
      </p>
    </div>

    <!-- Enhanced Logs Table -->
    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Resource</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Admin</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Changes</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <% @audit_logs.each do |log| %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full 
                           <%= log.event == 'create' ? 'bg-green-100 text-green-800' : 
                               log.event == 'destroy' ? 'bg-red-100 text-red-800' : 
                               'bg-yellow-100 text-yellow-800' %>">
                  <%= log.action_display %>
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-gray-900"><%= log.item_display_name %></div>
                <div class="text-sm text-gray-500"><%= log.item_type %></div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <%= log.admin_user&.email || 'System' %>
              </td>
              <td class="px-6 py-4">
                <div class="text-sm text-gray-900 max-w-xs truncate" title="<%= log.changes_summary %>">
                  <%= log.changes_summary %>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900"><%= log.created_at.strftime('%m/%d/%Y') %></div>
                <div class="text-sm text-gray-500"><%= log.created_at.strftime('%I:%M %p') %></div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                <%= link_to "View Details", admin_audit_log_path(log), class: "text-blue-600 hover:text-blue-900" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
      
      <% if @audit_logs.empty? %>
        <div class="text-center py-12">
          <p class="text-gray-500">No audit logs found matching your criteria.</p>
        </div>
      <% end %>
    </div>

    <!-- Pagination -->
    <% if respond_to?(:paginate) %>
      <div class="mt-6">
        <%= paginate @audit_logs %>
      </div>
    <% end %>
  ERB

  # Create admin user activities index view  
  create_file 'app/domains/admin/app/views/admin/user_activities/index.html.erb', <<~'ERB'
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-4">User Activities</h1>
      
      <!-- Filters -->
      <%= form_with url: admin_user_activities_path, method: :get, local: true, class: "bg-white p-4 rounded-lg shadow mb-6" do |f| %>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <%= f.label :user_id, "User", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :user_id, options_for_select([['All Users', '']] + @users.map { |u| [u.email, u.id] }, params[:user_id]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <div>
            <%= f.label :action_type, "Activity Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :action_type, options_for_select([['All Types', '']] + @action_types.map { |t| [t.humanize, t] }, params[:action_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <% if defined?(@workspaces) && @workspaces&.any? %>
          <div>
            <%= f.label :workspace_id, "Workspace", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :workspace_id, options_for_select([['All Workspaces', '']] + @workspaces.map { |w| [w.name, w.id] }, params[:workspace_id]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <% end %>
          <div>
            <%= f.label :resource_type, "Resource Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :resource_type, options_for_select([['All Resources', '']] + @resource_types.map { |t| [t, t] }, params[:resource_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div>
            <%= f.label :start_date, "Start Date", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :start_date, value: params[:start_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
          <div>
            <%= f.label :end_date, "End Date", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :end_date, value: params[:end_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
        </div>
        <div class="mt-4">
          <%= f.submit "Filter", class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
          <%= link_to "Clear", admin_user_activities_path, class: "ml-2 bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700" %>
        </div>
      <% end %>
    </div>

    <!-- Activity Timeline -->
    <div class="space-y-6">
      <% @user_activities.each do |activity| %>
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-start space-x-4">
            <!-- Activity Icon -->
            <div class="flex-shrink-0">
              <div class="w-10 h-10 rounded-full flex items-center justify-center
                         <%= activity.display_color == 'green' ? 'bg-green-100 text-green-600' :
                             activity.display_color == 'blue' ? 'bg-blue-100 text-blue-600' :
                             activity.display_color == 'red' ? 'bg-red-100 text-red-600' :
                             activity.display_color == 'purple' ? 'bg-purple-100 text-purple-600' :
                             'bg-gray-100 text-gray-600' %>">
                <i class="fas fa-<%= activity.icon_class %>"></i>
              </div>
            </div>
            
            <!-- Activity Content -->
            <div class="flex-grow">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-lg font-medium text-gray-900"><%= activity.description %></h3>
                  <p class="text-sm text-gray-500">
                    by <%= activity.user.email %>
                    <% if activity.workspace %>
                      in <span class="font-medium"><%= activity.workspace.name %></span>
                    <% end %>
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-sm text-gray-500"><%= time_ago_in_words(activity.created_at) %> ago</p>
                  <p class="text-xs text-gray-400"><%= activity.created_at.strftime('%m/%d/%Y %I:%M %p') %></p>
                </div>
              </div>
              
              <% if activity.resource %>
                <div class="mt-2">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    <%= activity.resource_type %>
                  </span>
                </div>
              <% end %>
              
              <% if activity.metadata.present? && activity.metadata.any? %>
                <div class="mt-3 text-sm text-gray-600">
                  <details>
                    <summary class="cursor-pointer hover:text-gray-800">View Details</summary>
                    <div class="mt-2 pl-4 border-l-2 border-gray-200">
                      <pre class="text-xs"><%= JSON.pretty_generate(activity.metadata) %></pre>
                    </div>
                  </details>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
      
      <% if @user_activities.empty? %>
        <div class="text-center py-12">
          <p class="text-gray-500">No user activities found matching your criteria.</p>
        </div>
      <% end %>
    </div>

    <!-- Pagination -->
    <% if respond_to?(:paginate) %>
      <div class="mt-6">
        <%= paginate @user_activities %>
      </div>
    <% end %>
  ERB

  # Create user activity feed for regular users
  create_file 'app/views/activity/index.html.erb', <<~'ERB'
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">My Activity</h1>
        <p class="text-gray-600 mt-2">Track your recent actions and important events.</p>
      </div>
      
      <!-- Filters -->
      <%= form_with url: activity_index_path, method: :get, local: true, class: "bg-white p-4 rounded-lg shadow mb-6" do |f| %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <% if defined?(@workspaces) && @workspaces&.any? %>
          <div>
            <%= f.label :workspace_id, "Workspace", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :workspace_id, options_for_select([['All Workspaces', '']] + @workspaces.map { |w| [w.name, w.id] }, params[:workspace_id]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <% end %>
          <div>
            <%= f.label :action_type, "Activity Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :action_type, options_for_select([['All Types', '']] + @action_types.map { |t| [t.humanize, t] }, params[:action_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
          <div>
            <%= f.label :resource_type, "Resource Type", class: "block text-sm font-medium text-gray-700" %>
            <%= f.select :resource_type, options_for_select([['All Resources', '']] + @resource_types.map { |t| [t, t] }, params[:resource_type]),
                        {}, { class: "mt-1 block w-full border-gray-300 rounded" } %>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div>
            <%= f.label :start_date, "From", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :start_date, value: params[:start_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
          <div>
            <%= f.label :end_date, "To", class: "block text-sm font-medium text-gray-700" %>
            <%= f.date_field :end_date, value: params[:end_date], class: "mt-1 block w-full border-gray-300 rounded" %>
          </div>
        </div>
        <div class="mt-4">
          <%= f.submit "Filter", class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
          <%= link_to "Clear", activity_index_path, class: "ml-2 bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700" %>
        </div>
      <% end %>

      <!-- Activity Timeline -->
      <div class="space-y-4">
        <% @activities.each do |activity| %>
          <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow">
            <div class="flex items-start space-x-3">
              <!-- Activity Icon -->
              <div class="flex-shrink-0">
                <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm
                           <%= activity.display_color == 'green' ? 'bg-green-100 text-green-600' :
                               activity.display_color == 'blue' ? 'bg-blue-100 text-blue-600' :
                               activity.display_color == 'red' ? 'bg-red-100 text-red-600' :
                               activity.display_color == 'purple' ? 'bg-purple-100 text-purple-600' :
                               'bg-gray-100 text-gray-600' %>">
                  <i class="fas fa-<%= activity.icon_class %>"></i>
                </div>
              </div>
              
              <!-- Activity Content -->
              <div class="flex-grow">
                <div class="flex items-center justify-between">
                  <h3 class="font-medium text-gray-900"><%= activity.description %></h3>
                  <time class="text-sm text-gray-500" datetime="<%= activity.created_at.iso8601 %>">
                    <%= time_ago_in_words(activity.created_at) %> ago
                  </time>
                </div>
                
                <% if activity.workspace %>
                  <p class="text-sm text-gray-600 mt-1">
                    in <span class="font-medium"><%= activity.workspace.name %></span>
                  </p>
                <% end %>
                
                <% if activity.resource %>
                  <div class="mt-2">
                    <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-gray-100 text-gray-700">
                      <%= activity.resource_type %>
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
        <% if @activities.empty? %>
          <div class="text-center py-12">
            <div class="text-gray-400">
              <i class="fas fa-clipboard-list text-4xl mb-4"></i>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No activities yet</h3>
            <p class="text-gray-500">Start using the platform to see your activity feed here.</p>
          </div>
        <% end %>
      </div>

      <!-- Pagination -->
      <% if respond_to?(:paginate) %>
        <div class="mt-8">
          <%= paginate @activities %>
        </div>
      <% end %>
    </div>
  ERB

  # Create feature flags index view
  create_file 'app/domains/admin/app/views/admin/feature_flags/index.html.erb', <<~'ERB'
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">Feature Flags</h1>
      <p class="text-gray-600">Control experimental features and rollout new functionality.</p>
    </div>

    <div class="bg-white shadow overflow-hidden sm:rounded-md">
      <ul class="divide-y divide-gray-200">
        <% @feature_flags.each do |flag| %>
          <li>
            <div class="px-4 py-4 flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <% if flag.enabled? %>
                    <div class="h-3 w-3 bg-green-500 rounded-full"></div>
                  <% else %>
                    <div class="h-3 w-3 bg-gray-300 rounded-full"></div>
                  <% end %>
                </div>
                <div class="ml-4">
                  <div class="text-sm font-medium text-gray-900"><%= flag.name %></div>
                  <div class="text-sm text-gray-500">
                    Status: 
                    <% if flag.enabled? %>
                      <span class="text-green-600 font-medium">Enabled</span>
                    <% else %>
                      <span class="text-gray-600">Disabled</span>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="flex space-x-2">
                <%= link_to "Details", admin_feature_flag_path(flag.name), class: "text-blue-600 hover:text-blue-800" %>
                <%= link_to flag.enabled? ? "Disable" : "Enable", 
                           admin_feature_flag_toggle_path(flag.name), 
                           method: :patch,
                           class: flag.enabled? ? "text-red-600 hover:text-red-800" : "text-green-600 hover:text-green-800",
                           data: { confirm: "#{flag.enabled? ? 'Disable' : 'Enable'} feature '#{flag.name}'?" } %>
              </div>
            </div>
          </li>
        <% end %>
      </ul>
    </div>

    <% if @feature_flags.empty? %>
      <div class="text-center py-12">
        <p class="text-gray-500">No feature flags configured yet.</p>
      </div>
    <% end %>
  ERB

  # Create user edit view
  create_file 'app/domains/admin/app/views/admin/users/edit.html.erb', <<~'ERB'
    <div class="mb-8">
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-gray-900">Edit User</h1>
        <%= link_to "← Back to User", admin_user_path(@user), class: "text-blue-600 hover:text-blue-800" %>
      </div>
    </div>

    <div class="bg-white shadow rounded-lg p-6 max-w-2xl">
      <%= form_with model: [:admin, @user], local: true, class: "space-y-6" do |f| %>
        <% if @user.errors.any? %>
          <div class="bg-red-50 border border-red-200 rounded p-4">
            <h3 class="text-red-800 font-medium">Please fix the following errors:</h3>
            <ul class="mt-2 text-red-700 text-sm">
              <% @user.errors.full_messages.each do |message| %>
                <li>• <%= message %></li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <div>
          <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
          <%= f.email_field :email, class: "mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" %>
        </div>

        <div>
          <%= f.label :admin, class: "flex items-center" %>
          <%= f.check_box :admin, class: "mr-2 rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <span class="text-sm text-gray-700">Grant admin privileges</span>
        </div>

        <div class="flex justify-end space-x-3">
          <%= link_to "Cancel", admin_user_path(@user), class: "bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700" %>
          <%= f.submit "Update User", class: "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700" %>
        </div>
      <% end %>
    </div>
  ERB

  # ==========================================
  # ROUTES
  # ==========================================

  # Add admin routes
  route <<~'RUBY'
    scope module: :admin do
      namespace :admin do
        root 'dashboard#index'
        get 'dashboard', to: 'dashboard#index'
        
        resources :users do
          member do
            post :impersonate
          end
        end
        
        delete 'stop_impersonation', to: 'users#stop_impersonation'
        
        resources :audit_logs, only: [:index, :show] do
          collection do
            get :export
          end
        end
        
        resources :user_activities, only: [:index, :show]
        
        resources :feature_flags, only: [:index, :show] do
          member do
            patch :toggle
            patch :update_percentage
          end
        end
      end
    end
  RUBY

  # Add user activity feed routes
  route <<~'RUBY'
    resources :activity, only: [:index, :show], path: 'activity'
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
  generate :migration, 'add_admin_to_users', <<~RUBY
    class AddAdminToUsers < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]
      def change
        add_column :users, :admin, :boolean, default: false, null: false
        add_index :users, :admin
      end
    end
  RUBY

  # Create user activities migration
  generate :migration, 'create_user_activities', <<~RUBY
    class CreateUserActivities < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]
      def change
        create_table :user_activities do |t|
          t.references :user, null: false, foreign_key: true, index: true
          t.references :workspace, null: true, foreign_key: true, index: true
          t.references :resource, polymorphic: true, null: true, index: true
          t.string :action, null: false, index: true
          t.text :description, null: false
          t.json :metadata, default: {}
          t.string :ip_address
          t.text :user_agent
          t.timestamps

          t.index [:user_id, :created_at]
          t.index [:workspace_id, :created_at]
          t.index [:action, :created_at]
          t.index :created_at
        end
      end
    end
  RUBY

  # ==========================================
  # TESTS
  # ==========================================

  # Create admin controller tests
  create_file 'spec/domains/admin/controllers/dashboard_controller_spec.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.describe Admin::DashboardController, type: :controller do
      before do
        @admin_user = create(:user, :admin)
        @regular_user = create(:user)
      end

      context 'admin user' do
        before { sign_in @admin_user }

        it 'can access dashboard' do
          get :index
          expect(response).to be_successful
        end
      end

      context 'regular user' do
        before { sign_in @regular_user }

        it 'cannot access dashboard' do
          get :index
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq('Access denied.')
        end
      end

      context 'guest user' do
        it 'cannot access dashboard' do
          get :index
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  RUBY

  # Create UserActivity model tests
  create_file 'spec/domains/admin/models/user_activity_spec.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.describe UserActivity, type: :model do
      describe 'associations' do
        it { should belong_to(:user) }
        it { should belong_to(:workspace).optional }
        it { should belong_to(:resource).optional }
      end

      describe 'validations' do
        it { should validate_presence_of(:action) }
        it { should validate_presence_of(:description) }
        it { should validate_inclusion_of(:action).in_array(UserActivity::ACTIVITY_TYPES) }
      end

      describe 'scopes' do
        let(:user) { create(:user) }
        let(:workspace) { create(:workspace) if defined?(Workspace) }
        let!(:recent_activity) { create(:user_activity, user: user, created_at: 1.hour.ago) }
        let!(:old_activity) { create(:user_activity, user: user, created_at: 1.week.ago) }

        describe '.recent' do
          it 'returns activities in reverse chronological order' do
            expect(UserActivity.recent.first).to eq(recent_activity)
          end
        end

        describe '.for_workspace' do
          it 'returns activities for specific workspace' do
            if workspace
              workspace_activity = create(:user_activity, user: user, workspace: workspace)
              expect(UserActivity.for_workspace(workspace.id)).to include(workspace_activity)
            end
          end
        end

        describe '.by_action' do
          it 'returns activities with specific action' do
            create_activity = create(:user_activity, user: user, action: 'create')
            expect(UserActivity.by_action('create')).to include(create_activity)
          end
        end
      end

      describe '.log_user_activity' do
        let(:user) { create(:user) }

        it 'creates a new user activity' do
          expect {
            UserActivity.log_user_activity(
              user: user,
              action: 'create',
              description: 'Created a new workspace'
            )
          }.to change { UserActivity.count }.by(1)

          activity = UserActivity.last
          expect(activity.user).to eq(user)
          expect(activity.action).to eq('create')
          expect(activity.description).to eq('Created a new workspace')
        end
      end

      describe '#icon_class' do
        let(:user) { create(:user) }

        it 'returns correct icon for create actions' do
          activity = create(:user_activity, user: user, action: 'create')
          expect(activity.icon_class).to eq('plus-circle')
        end

        it 'returns correct icon for update actions' do
          activity = create(:user_activity, user: user, action: 'update')
          expect(activity.icon_class).to eq('pencil')
        end

        it 'returns correct icon for destroy actions' do
          activity = create(:user_activity, user: user, action: 'destroy')
          expect(activity.icon_class).to eq('trash')
        end
      end

      describe '#display_color' do
        let(:user) { create(:user) }

        it 'returns green for create actions' do
          activity = create(:user_activity, user: user, action: 'create')
          expect(activity.display_color).to eq('green')
        end

        it 'returns blue for update actions' do
          activity = create(:user_activity, user: user, action: 'update')
          expect(activity.display_color).to eq('blue')
        end

        it 'returns red for destroy actions' do
          activity = create(:user_activity, user: user, action: 'destroy')
          expect(activity.display_color).to eq('red')
        end
      end
    end
  RUBY

  # Create enhanced AuditLog tests
  create_file 'spec/domains/admin/models/enhanced_audit_log_spec.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.describe AuditLog, type: :model do
      describe 'enhanced scopes' do
        let(:user) { create(:user) }
        let(:workspace) { create(:workspace) if defined?(Workspace) }
        let!(:user_log) { create(:audit_log, item: user) }
        let!(:create_log) { create(:audit_log, event: 'create') }
        let!(:update_log) { create(:audit_log, event: 'update') }

        describe '.for_workspace' do
          it 'returns logs for specific workspace' do
            if workspace
              workspace_log = create(:audit_log, item: workspace)
              # This test assumes the item has a workspace_id
              expect(AuditLog.for_workspace(workspace.id)).to be_present
            end
          end
        end

        describe '.by_event_type' do
          it 'returns logs for specific event type' do
            expect(AuditLog.by_event_type('create')).to include(create_log)
            expect(AuditLog.by_event_type('create')).not_to include(update_log)
          end
        end
      end

      describe '.log_action' do
        let(:user) { create(:user) }
        let(:resource) { create(:user) }

        it 'creates audit log with specified parameters' do
          changes = { 'email' => ['old@example.com', 'new@example.com'] }
          
          expect {
            AuditLog.log_action(
              user: user,
              action: 'update',
              resource: resource,
              changes: changes
            )
          }.to change { AuditLog.count }.by(1)

          log = AuditLog.last
          expect(log.whodunnit).to eq(user.id.to_s)
          expect(log.event).to eq('update')
          expect(log.item).to eq(resource)
        end
      end

      describe '#formatted_changes' do
        let(:audit_log) { create(:audit_log, :update_action) }

        it 'returns formatted changes' do
          formatted = audit_log.formatted_changes
          expect(formatted).to include('→')
          expect(formatted).to be_a(String)
        end

        it 'handles empty changes' do
          audit_log.update(object_changes: nil)
          expect(audit_log.formatted_changes).to eq('No changes recorded')
        end
      end
    end
  RUBY

  # Create user activities controller tests
  create_file 'spec/domains/admin/controllers/user_activities_controller_spec.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.describe Admin::UserActivitiesController, type: :controller do
      let(:admin_user) { create(:user, :admin) }
      let(:regular_user) { create(:user) }

      before { sign_in admin_user }

      describe 'GET #index' do
        let!(:user_activity) { create(:user_activity, user: regular_user) }

        it 'returns successful response' do
          get :index
          expect(response).to be_successful
        end

        it 'assigns user activities' do
          get :index
          expect(assigns(:user_activities)).to include(user_activity)
        end

        it 'filters by user_id' do
          other_user = create(:user)
          other_activity = create(:user_activity, user: other_user)
          
          get :index, params: { user_id: regular_user.id }
          
          expect(assigns(:user_activities)).to include(user_activity)
          expect(assigns(:user_activities)).not_to include(other_activity)
        end
      end

      describe 'GET #show' do
        let(:user_activity) { create(:user_activity, user: regular_user) }

        it 'returns successful response' do
          get :show, params: { id: user_activity.id }
          expect(response).to be_successful
        end

        it 'assigns the user activity' do
          get :show, params: { id: user_activity.id }
          expect(assigns(:user_activity)).to eq(user_activity)
        end
      end
    end
  RUBY

  # Create activity controller tests (for regular users)
  create_file 'spec/controllers/activity_controller_spec.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.describe ActivityController, type: :controller do
      let(:user) { create(:user) }

      before { sign_in user }

      describe 'GET #index' do
        let!(:user_activity) { create(:user_activity, user: user) }
        let!(:other_activity) { create(:user_activity, user: create(:user)) }

        it 'returns successful response' do
          get :index
          expect(response).to be_successful
        end

        it 'shows only current user activities' do
          get :index
          expect(assigns(:activities)).to include(user_activity)
          expect(assigns(:activities)).not_to include(other_activity)
        end

        it 'filters by action type' do
          create_activity = create(:user_activity, user: user, action: 'create')
          update_activity = create(:user_activity, user: user, action: 'update')
          
          get :index, params: { action_type: 'create' }
          
          expect(assigns(:activities)).to include(create_activity)
          expect(assigns(:activities)).not_to include(update_activity)
        end
      end

      describe 'GET #show' do
        let(:user_activity) { create(:user_activity, user: user) }

        it 'returns successful response' do
          get :show, params: { id: user_activity.id }
          expect(response).to be_successful
        end

        it 'assigns the user activity' do
          get :show, params: { id: user_activity.id }
          expect(assigns(:activity)).to eq(user_activity)
        end

        it 'does not allow viewing other users activities' do
          other_activity = create(:user_activity, user: create(:user))
          
          expect {
            get :show, params: { id: other_activity.id }
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  RUBY

  # Update factories to include user activities
  create_file 'spec/domains/admin/factories/user_activities.rb', <<~'RUBY'
    FactoryBot.define do
      factory :user_activity do
        user
        action { 'create' }
        description { 'Created a new resource' }
        workspace { nil }
        resource { nil }
        metadata { {} }
        ip_address { '192.168.1.1' }
        user_agent { 'Mozilla/5.0' }

        trait :create_action do
          action { 'create' }
          description { 'Created a new workspace' }
        end

        trait :update_action do
          action { 'update' }
          description { 'Updated workspace settings' }
        end

        trait :destroy_action do
          action { 'destroy' }
          description { 'Deleted a workspace' }
        end

        trait :with_workspace do
          workspace { create(:workspace) if defined?(Workspace) }
        end

        trait :with_metadata do
          metadata { { 'changes' => { 'name' => ['Old Name', 'New Name'] } } }
        end
      end
    end
  RUBY

  # Create fixtures for testing
  create_file 'spec/domains/admin/fixtures/users.yml', <<~'YAML'
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
  # gem 'request_store' # Moved to top

  # Add kaminari for pagination
  # gem 'kaminari' # Moved to top

  say_status :synth_admin, "Admin panel with user activity feed installed successfully!"
  say_status :synth_admin, "New Features Added:"
  say_status :synth_admin, "• User activity feed for end users at /activity"
  say_status :synth_admin, "• Enhanced audit logs with filtering and CSV export"
  say_status :synth_admin, "• Timeline UI components for activity display"
  say_status :synth_admin, "• Admin user activities dashboard at /admin/user_activities"
  say_status :synth_admin, ""
  say_status :synth_admin, "Next steps:"
  say_status :synth_admin, "1. Run: rails db:migrate"
  say_status :synth_admin, "2. Create an admin user: User.create!(email: 'admin@example.com', password: 'password', admin: true)"
  say_status :synth_admin, "3. Visit /admin to access the admin panel"
  say_status :synth_admin, "4. Visit /activity to see the user activity feed"
  say_status :synth_admin, "5. Configure Sidekiq and Flipper credentials in Rails credentials"
  say_status :synth_admin, "6. Include ActivityTrackable concern in models you want to track"
end
