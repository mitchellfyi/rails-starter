# frozen_string_literal: true

# API module main installer

say_status :railsplan_api, "Installing API module"

# Load gem dependencies  
load File.join(__dir__, 'install_modules', 'gems.rb')

after_bundle do
  # Create directory structure
  run 'mkdir -p app/domains/api/app/controllers/api/v1'
  run 'mkdir -p app/domains/api/app/serializers'
  run 'mkdir -p app/domains/api/app/services'
  run 'mkdir -p swagger/v1'
  
  # Set up configuration
  load File.join(__dir__, 'install_modules', 'config.rb')
  
  # Generate Rswag files
  generate 'rswag:install'
  
  # Copy application files
  directory 'app', 'app/domains/api/app', force: true
  
  # Copy swagger files
  directory 'swagger', 'swagger', force: true
  
  # Add routes
  route <<~RUBY
    # API module routes
    namespace :api do
      namespace :v1 do
        resources :users, only: [:index, :show, :create, :update, :destroy]
        resources :auth, only: [] do
          collection do
            post :login
            delete :logout
            post :refresh
          end
        end
      end
    end
    
    # API documentation
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  RUBY
  
  say_status :railsplan_api, "✅ API module installed successfully!"
  say_status :railsplan_api, "📖 Access API documentation at /api-docs"
  say_status :railsplan_api, "🔑 Configure API authentication in config/initializers/api.rb"
  say_status :railsplan_api, "📊 API endpoints available at /api/v1/"
end