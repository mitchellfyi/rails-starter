# frozen_string_literal: true

# Admin module main installer
# This is the main installer that orchestrates all admin module components

say_status :synth_admin, "Installing Admin Panel module"

# Load gem dependencies
load File.join(__dir__, 'install_modules', 'gems.rb')

after_bundle do
  # Create directory structure
  load File.join(__dir__, 'install_modules', 'structure.rb')
  
  # Set up configuration
  load File.join(__dir__, 'install_modules', 'config.rb')
  
  # Set up migrations
  load File.join(__dir__, 'install_modules', 'migrations.rb')
  
  # Copy application files
  directory 'app', 'app/domains/admin/app', force: true
  
  # Copy configuration files
  directory 'config', 'config', force: true
  
  # Add routes
  route <<~RUBY
    # Admin module routes
    namespace :admin do
      root 'dashboard#index'
      resources :users do
        member do
          post :impersonate
          delete :stop_impersonating
        end
      end
      resources :audit_logs, only: [:index, :show]
      resources :feature_flags, only: [:index, :update]
      mount Flipper::UI.app(Flipper) => '/feature_flags', as: :flipper
      mount Sidekiq::Web => '/sidekiq'
    end
  RUBY
  
  # Run final setup
  generate 'paper_trail:install'
  
  say_status :synth_admin, "✅ Admin Panel module installed successfully!"
  say_status :synth_admin, "📝 Run 'rails db:migrate' to apply admin database changes"
  say_status :synth_admin, "🔧 Configure admin settings in config/initializers/admin.rb"
  say_status :synth_admin, "🌟 Access admin panel at /admin (requires admin user)"
end