# frozen_string_literal: true

# Installer for the Workspace module.
# This module provides workspace/team management with slug routing,
# invitation system, and role-based permissions.

say 'Installing Workspace module...'

# Create domain-specific directories (models stay in central app/models)
run 'mkdir -p app/domains/workspaces/app/{controllers,mailers,policies,views/invitations,views/memberships,views/workspaces,views/invitation_mailer}'
run 'mkdir -p app/models/concerns' # Ensure models directory exists
run 'mkdir -p spec/domains/workspaces/{models,controllers,integration,fixtures}'

# Check if Pundit is in Gemfile
unless File.read('Gemfile').include?('pundit')
  say 'Adding Pundit gem for authorization...'
  gem 'pundit', '~> 2.1'
  run 'bundle install'
end

# Generate enhanced models (skip if they already exist)
if File.exist?('app/models/workspace.rb')
  say 'Workspace model already exists, skipping generation...'
else
  generate :model, 'Workspace', 'name:string', 'slug:string:uniq', 'description:text', 'created_by:references'
end

if File.exist?('app/models/membership.rb')
  say 'Membership model already exists, skipping generation...'
else  
  generate :model, 'Membership', 'workspace:references', 'user:references', 'role:string', 'invited_by:references:user', 'joined_at:datetime'
end

if File.exist?('app/models/invitation.rb')
  say 'Invitation model already exists, skipping generation...'
else
  generate :model, 'Invitation', 'workspace:references', 'email:string', 'role:string', 'token:string:uniq', 'invited_by:references:user', 'accepted_at:datetime', 'expires_at:datetime'
end

# Generate controllers
generate :controller, 'Workspaces', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy', dir: 'app/domains/workspaces/app/controllers' unless File.exist?('app/controllers/workspaces_controller.rb')
generate :controller, 'Memberships', 'index', 'create', 'update', 'destroy', dir: 'app/domains/workspaces/app/controllers' unless File.exist?('app/controllers/memberships_controller.rb')
generate :controller, 'Invitations', 'show', 'create', 'accept', 'decline', dir: 'app/domains/workspaces/app/controllers' unless File.exist?('app/controllers/invitations_controller.rb')

# Generate mailer for invitations
generate :mailer, 'InvitationMailer', 'invite_user', dir: 'app/domains/workspaces/app/mailers' unless File.exist?('app/mailers/invitation_mailer.rb')

# Install Pundit if not already configured
unless File.exist?('app/controllers/application_controller.rb') && File.read('app/controllers/application_controller.rb').include?('include Pundit')
  say 'Configuring Pundit authorization...'
  inject_into_class 'app/domains/workspaces/app/controllers/application_controller.rb', 'ApplicationController' do
    <<~RUBY
      include Pundit::Authorization
      
      # Pundit authorization
      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
      
      private
      
      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_to(request.referrer || root_path)
      end
    RUBY
  end
end

# Add routes (check if routes don't already exist)
routes_content = File.read('config/routes.rb')
unless routes_content.include?('resources :workspaces')
  route <<~ROUTES
    scope module: :workspaces do
      resources :workspaces, param: :slug do
        resources :memberships, except: [:show, :new, :edit]
        resources :invitations, only: [:show, :create] do
          member do
            patch :accept
            patch :decline
          end
        end
      end
      
      # Public invitation routes
      get '/invitations/:id', to: 'invitations#show', as: 'invitation'
      patch '/invitations/:id/accept', to: 'invitations#accept', as: 'accept_invitation'
      patch '/invitations/:id/decline', to: 'invitations#decline', as: 'decline_invitation'
    end
  ROUTES
end

# Copy enhanced model files
say 'Copying enhanced model files...'
template_dir = File.expand_path('lib/templates/railsplan/workspace', Rails.root)

copy_file File.join(template_dir, 'app/models/workspace.rb'), 'app/models/workspace.rb', force: true
copy_file File.join(template_dir, 'app/models/membership.rb'), 'app/models/membership.rb', force: true  
copy_file File.join(template_dir, 'app/models/invitation.rb'), 'app/models/invitation.rb', force: true

# Copy controllers
copy_file File.join(template_dir, 'app/controllers/workspaces_controller.rb'), 'app/domains/workspaces/app/controllers/workspaces_controller.rb', force: true
copy_file File.join(template_dir, 'app/controllers/memberships_controller.rb'), 'app/domains/workspaces/app/controllers/memberships_controller.rb', force: true
copy_file File.join(template_dir, 'app/controllers/invitations_controller.rb'), 'app/domains/workspaces/app/controllers/invitations_controller.rb', force: true

# Copy concerns
directory File.join(template_dir, 'app/controllers/concerns'), 'app/domains/workspaces/app/controllers/concerns'
directory File.join(template_dir, 'app/models/concerns'), 'app/models/concerns'

# Copy policies
directory File.join(template_dir, 'app/policies'), 'app/domains/workspaces/app/policies'

# Copy mailer
copy_file File.join(template_dir, 'app/mailers/invitation_mailer.rb'), 'app/domains/workspaces/app/mailers/invitation_mailer.rb', force: true

# Copy views
directory File.join(template_dir, 'app/views'), 'app/domains/workspaces/app/views'

# Update User model to include workspace extensions
user_model_path = 'app/models/user.rb'
if File.exist?(user_model_path)
  user_content = File.read(user_model_path)
  unless user_content.include?('UserWorkspaceExtensions')
    say 'Adding workspace extensions to User model...'
    inject_into_class user_model_path, 'User' do
      "  include UserWorkspaceExtensions\n"
    end
  end
end

say 'Workspace module installation complete!'
say ''
say 'Next steps:'
say '1. Run: rails db:migrate'
say '2. Configure email delivery in your environment files'
say '3. Add workspace navigation to your layout'
say '4. Customize the workspace views to match your design'
say ''
say 'For more information, see: app/domains/workspaces/README.md'