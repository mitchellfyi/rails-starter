# frozen_string_literal: true

# Admin module installer
say 'Installing Admin module...'

# Add admin field to users if it doesn't exist
unless ActiveRecord::Base.connection.column_exists?(:users, :admin)
  generate :migration, 'AddAdminToUsers', 'admin:boolean'
end

# Create admin models
generate :model, 'AuditLog', 'user:references', 'action:string', 'resource_type:string', 'resource_id:integer', 'changes:text'
generate :model, 'FeatureFlag', 'name:string', 'enabled:boolean', 'description:text'

# Create admin controllers
generate :controller, 'Admin::Dashboard', 'index'
generate :controller, 'Admin::Users', 'index', 'show', 'edit', 'update'
generate :controller, 'Admin::AuditLogs', 'index', 'show'
generate :controller, 'Admin::FeatureFlags', 'index', 'update'

# Add admin routes with authentication check
route "namespace :admin do\n  authenticate :user, lambda { |u| u.admin? } do\n    root 'dashboard#index'\n    resources :users, except: [:new, :create, :destroy]\n    resources :audit_logs, only: [:index, :show]\n    resources :feature_flags, only: [:index, :update]\n  end\nend"

say 'Admin module installed! Users with admin=true can access /admin'