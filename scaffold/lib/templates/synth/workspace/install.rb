# frozen_string_literal: true

# Installer for the Workspace module.
# This module provides workspace/team management with slug routing,
# invitation system, and role-based permissions.

say 'Installing Workspace module...'

# Generate enhanced models
generate :model, 'Workspace', 'name:string', 'slug:string:uniq', 'description:text', 'created_by:references'
generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string', 'invited_by:references', 'joined_at:datetime'
generate :model, 'Invitation', 'workspace:references', 'email:string', 'role:string', 'token:string:uniq', 'invited_by:references', 'accepted_at:datetime', 'expires_at:datetime'

# Generate controllers
generate :controller, 'Workspaces', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
generate :controller, 'Memberships', 'index', 'create', 'update', 'destroy'
generate :controller, 'Invitations', 'show', 'create', 'accept', 'decline'

# Add routes
route <<~ROUTES
  resources :workspaces, param: :slug do
    resources :memberships, except: [:show, :new, :edit]
    resources :invitations, only: [:show, :create, :accept, :decline] do
      member do
        patch :accept
        patch :decline
      end
    end
  end
  
  # Root workspace redirect
  root 'workspaces#index'
ROUTES

# Generate mailers for invitations
generate :mailer, 'InvitationMailer', 'invite_user'

# Create policy files for authorization
create_file 'app/policies/application_policy.rb', <<~RUBY
  # frozen_string_literal: true
  
  class ApplicationPolicy
    attr_reader :user, :record
  
    def initialize(user, record)
      @user = user
      @record = record
    end
  
    def index?
      false
    end
  
    def show?
      false
    end
  
    def create?
      false
    end
  
    def new?
      create?
    end
  
    def update?
      false
    end
  
    def edit?
      update?
    end
  
    def destroy?
      false
    end
  
    class Scope
      def initialize(user, scope)
        @user = user
        @scope = scope
      end
  
      def resolve
        raise NotImplementedError, "You must define #resolve in #{self.class}"
      end
  
      private
  
      attr_reader :user, :scope
    end
  end
RUBY

create_file 'app/policies/workspace_policy.rb', <<~RUBY
  # frozen_string_literal: true
  
  class WorkspacePolicy < ApplicationPolicy
    def index?
      user.present?
    end
  
    def show?
      user.present? && (workspace_member? || workspace_admin?)
    end
  
    def create?
      user.present?
    end
  
    def update?
      workspace_admin?
    end
  
    def destroy?
      workspace_admin?
    end
  
    def manage_members?
      workspace_admin?
    end
  
    private
  
    def workspace_member?
      record.memberships.exists?(user: user)
    end
  
    def workspace_admin?
      record.memberships.exists?(user: user, role: 'admin')
    end
  
    class Scope < Scope
      def resolve
        return scope.none unless user
        
        scope.joins(:memberships).where(memberships: { user: user })
      end
    end
  end
RUBY

create_file 'app/policies/membership_policy.rb', <<~RUBY
  # frozen_string_literal: true
  
  class MembershipPolicy < ApplicationPolicy
    def index?
      workspace_member?
    end
  
    def create?
      workspace_admin?
    end
  
    def update?
      workspace_admin? || own_membership?
    end
  
    def destroy?
      workspace_admin? || own_membership?
    end
  
    private
  
    def workspace_member?
      record.workspace.memberships.exists?(user: user)
    end
  
    def workspace_admin?
      record.workspace.memberships.exists?(user: user, role: 'admin')
    end
  
    def own_membership?
      record.user == user
    end
  end
RUBY

# Add application controller concern for workspace handling
create_file 'app/controllers/concerns/workspace_scoped.rb', <<~RUBY
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
RUBY

say 'Workspace module installation complete!'
say 'Remember to run: rails db:migrate'
say 'Configure your environment variables for email delivery.'