# frozen_string_literal: true

# Synth Admin module installer for the Rails SaaS starter template.
# This module creates an admin panel with user management, audit logs, and feature flags.

say_status :admin, "Installing admin module with dashboard and audit logs"

# Add admin-specific gems
add_gem 'pundit', '~> 2.4'
add_gem 'kaminari', '~> 1.2'
add_gem 'audited', '~> 5.8'
add_gem 'flipper', '~> 1.4'
add_gem 'flipper-active_record', '~> 1.4'
add_gem 'flipper-ui', '~> 1.4'

after_bundle do
  # Install Pundit
  generate 'pundit:install'
  
  # Install Audited
  generate 'audited:install'
  
  # Install Flipper
  generate 'flipper:active_record'

  # Create admin base controller
  create_file 'app/controllers/admin/base_controller.rb', <<~'RUBY'
    class Admin::BaseController < ApplicationController
      include Pundit::Authorization
      
      before_action :authenticate_user!
      before_action :ensure_admin!
      
      layout 'admin'
      
      rescue_from Pundit::NotAuthorizedError, with: :admin_not_authorized

      private

      def ensure_admin!
        redirect_to root_path unless current_user.admin?
      end

      def admin_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_to admin_root_path
      end
    end
  RUBY

  # Create admin dashboard controller
  create_file 'app/controllers/admin/dashboard_controller.rb', <<~'RUBY'
    class Admin::DashboardController < Admin::BaseController
      def index
        @stats = {
          total_users: User.count,
          users_this_week: User.where('created_at > ?', 1.week.ago).count,
          total_posts: defined?(Post) ? Post.count : 0,
          published_posts: defined?(Post) ? Post.published.count : 0
        }
        
        @recent_users = User.order(created_at: :desc).limit(5)
        @recent_audits = Audited::Audit.order(created_at: :desc).limit(10)
      end
    end
  RUBY

  # Create admin users controller
  create_file 'app/controllers/admin/users_controller.rb', <<~'RUBY'
    class Admin::UsersController < Admin::BaseController
      before_action :set_user, only: [:show, :edit, :update, :destroy, :impersonate, :stop_impersonating]

      def index
        @users = User.page(params[:page]).per(25)
        @users = @users.where('email ILIKE ?', "%#{params[:search]}%") if params[:search].present?
        authorize @users
      end

      def show
        authorize @user
        @audits = @user.audits.order(created_at: :desc).limit(20)
      end

      def edit
        authorize @user
      end

      def update
        authorize @user
        
        if @user.update(user_params)
          redirect_to admin_user_path(@user), notice: 'User updated successfully.'
        else
          render :edit
        end
      end

      def destroy
        authorize @user
        
        if @user.destroy
          redirect_to admin_users_path, notice: 'User deleted successfully.'
        else
          redirect_to admin_user_path(@user), alert: 'Failed to delete user.'
        end
      end

      def impersonate
        authorize @user
        
        impersonate_user(@user)
        redirect_to root_path, notice: "Now impersonating #{@user.full_name}"
      end

      def stop_impersonating
        stop_impersonating_user
        redirect_to admin_users_path, notice: 'Stopped impersonating user'
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:first_name, :last_name, :email, :admin)
      end
    end
  RUBY

  # Create admin audit logs controller
  create_file 'app/controllers/admin/audit_logs_controller.rb', <<~'RUBY'
    class Admin::AuditLogsController < Admin::BaseController
      def index
        @audits = Audited::Audit.includes(:user).order(created_at: :desc)
        @audits = @audits.where(auditable_type: params[:model]) if params[:model].present?
        @audits = @audits.where(action: params[:action]) if params[:action].present?
        @audits = @audits.page(params[:page]).per(50)
        
        authorize @audits
      end

      def show
        @audit = Audited::Audit.find(params[:id])
        authorize @audit
      end
    end
  RUBY

  # Create admin feature flags controller
  create_file 'app/controllers/admin/feature_flags_controller.rb', <<~'RUBY'
    class Admin::FeatureFlagsController < Admin::BaseController
      def index
        @features = Flipper.features.map do |feature|
          {
            name: feature.name,
            enabled: feature.enabled?,
            gates: feature.gates.map(&:name)
          }
        end
        
        authorize :feature_flag, :index?
      end

      def update
        authorize :feature_flag, :update?
        
        feature = Flipper[params[:id]]
        
        if params[:enabled] == 'true'
          feature.enable
          message = "Feature '#{params[:id]}' enabled"
        else
          feature.disable
          message = "Feature '#{params[:id]}' disabled"
        end
        
        redirect_to admin_feature_flags_path, notice: message
      end
    end
  RUBY

  # Create admin policies
  create_file 'app/policies/admin_policy.rb', <<~'RUBY'
    class AdminPolicy < ApplicationPolicy
      def index?
        user.admin?
      end

      def show?
        user.admin?
      end

      def create?
        user.admin?
      end

      def update?
        user.admin?
      end

      def destroy?
        user.admin?
      end

      class Scope < Scope
        def resolve
          user.admin? ? scope.all : scope.none
        end
      end
    end
  RUBY

  create_file 'app/policies/user_policy.rb', <<~'RUBY'
    class UserPolicy < ApplicationPolicy
      def index?
        user.admin?
      end

      def show?
        user.admin? || user == record
      end

      def create?
        user.admin?
      end

      def update?
        user.admin? || user == record
      end

      def destroy?
        user.admin? && user != record
      end

      def impersonate?
        user.admin? && user != record
      end

      class Scope < Scope
        def resolve
          user.admin? ? scope.all : scope.where(id: user.id)
        end
      end
    end
  RUBY

  create_file 'app/policies/feature_flag_policy.rb', <<~'RUBY'
    class FeatureFlagPolicy < ApplicationPolicy
      def index?
        user.admin?
      end

      def update?
        user.admin?
      end
    end
  RUBY

  # Create admin layout
  create_file 'app/views/layouts/admin.html.erb', <<~'ERB'
    <!DOCTYPE html>
    <html>
      <head>
        <title>Admin Panel - <%= Rails.application.class.name.split('::').first %></title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        
        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
      </head>

      <body class="admin-layout">
        <nav class="admin-nav">
          <%= link_to "Dashboard", admin_root_path, class: "nav-link" %>
          <%= link_to "Users", admin_users_path, class: "nav-link" %>
          <%= link_to "Audit Logs", admin_audit_logs_path, class: "nav-link" %>
          <%= link_to "Feature Flags", admin_feature_flags_path, class: "nav-link" %>
          
          <div class="nav-user">
            <%= current_user.full_name %>
            <%= link_to "Back to Site", root_path, class: "nav-link" %>
            <%= link_to "Logout", destroy_user_session_path, method: :delete, class: "nav-link" %>
          </div>
        </nav>

        <main class="admin-content">
          <% if notice %>
            <div class="alert alert-success"><%= notice %></div>
          <% end %>
          
          <% if alert %>
            <div class="alert alert-danger"><%= alert %></div>
          <% end %>

          <%= yield %>
        </main>
      </body>
    </html>
  ERB

  # Create impersonation helpers
  create_file 'app/models/concerns/impersonatable.rb', <<~'RUBY'
    module Impersonatable
      extend ActiveSupport::Concern

      included do
        attr_accessor :impersonator_id
      end

      def impersonating?
        impersonator_id.present?
      end

      def impersonator
        return nil unless impersonating?
        User.find(impersonator_id)
      end
    end
  RUBY

  say_status :admin, "Admin module installed. Next steps:"
  say_status :admin, "1. Run rails db:migrate"
  say_status :admin, "2. Add admin routes"
  say_status :admin, "3. Add admin? field to User model"
  say_status :admin, "4. Include Impersonatable concern in User model"
  say_status :admin, "5. Configure Flipper feature flags"
end