# frozen_string_literal: true

# Installer for the Onboarding module.
# This module provides wizard-style onboarding for new users with
# adaptive steps based on installed modules.

say 'Installing Onboarding module...'

# Create domain-specific directories
run 'mkdir -p app/domains/onboarding/app/{controllers,models,services,views/onboarding/steps,views/onboarding/partials}'
run 'mkdir -p spec/domains/onboarding/{models,controllers,services,integration,fixtures}'

# Generate the OnboardingProgress model
generate :model, 'OnboardingProgress', 
  'user:references',
  'current_step:string',
  'completed_steps:json',
  'skipped:boolean:default=false',
  'completed_at:datetime',
  dir: 'app/domains/onboarding/app/models'

# Copy model files
copy_file 'app/models/onboarding_progress.rb', 'app/domains/onboarding/app/models/onboarding_progress.rb'

# Copy controller files
copy_file 'app/controllers/onboarding_controller.rb', 'app/domains/onboarding/app/controllers/onboarding_controller.rb'

# Copy service files
copy_file 'app/services/onboarding_step_handler.rb', 'app/domains/onboarding/app/services/onboarding_step_handler.rb'
copy_file 'app/services/module_detector.rb', 'app/domains/onboarding/app/services/module_detector.rb'

# Copy view files
copy_file 'app/views/onboarding/index.html.erb', 'app/domains/onboarding/app/views/onboarding/index.html.erb'
copy_file 'app/views/onboarding/show.html.erb', 'app/domains/onboarding/app/views/onboarding/show.html.erb'

# Copy step views
%w[welcome create_workspace invite_colleagues connect_billing connect_ai explore_features complete].each do |step|
  copy_file "app/views/onboarding/steps/_#{step}.html.erb", "app/domains/onboarding/app/views/onboarding/steps/_#{step}.html.erb"
end

# Copy partial views
copy_file 'app/views/onboarding/partials/_progress.html.erb', 'app/domains/onboarding/app/views/onboarding/partials/_progress.html.erb'
copy_file 'app/views/onboarding/partials/_navigation.html.erb', 'app/domains/onboarding/app/views/onboarding/partials/_navigation.html.erb'

# Copy concern for User model
copy_file 'app/models/concerns/onboardable.rb', 'app/domains/onboarding/app/models/concerns/onboardable.rb'

# Add routes
route_content = <<~RUBY
  # Onboarding routes
  get '/onboarding', to: 'onboarding#index'
  get '/onboarding/step/:step', to: 'onboarding#show', as: 'onboarding_step'
  post '/onboarding/step/:step', to: 'onboarding#update'
  post '/onboarding/skip', to: 'onboarding#skip'
  post '/onboarding/resume', to: 'onboarding#resume'
RUBY

# Add routes to config/routes.rb if they don't exist
routes_file = File.read('config/routes.rb')
unless routes_file.include?('onboarding')
  inject_into_file 'config/routes.rb', route_content, after: "Rails.application.routes.draw do\n"
end

# Add onboarding concern to User model
user_model_path = 'app/models/user.rb'
if File.exist?(user_model_path)
  user_content = File.read(user_model_path)
  unless user_content.include?('include Onboardable')
    inject_into_class user_model_path, 'User', "  include Onboardable\n"
  end
end

# Copy test files
copy_file 'test/models/onboarding_progress_test.rb', 'app/domains/onboarding/test/models/onboarding_progress_test.rb'
copy_file 'test/controllers/onboarding_controller_test.rb', 'app/domains/onboarding/test/controllers/onboarding_controller_test.rb'
copy_file 'test/services/onboarding_step_handler_test.rb', 'app/domains/onboarding/test/services/onboarding_step_handler_test.rb'
copy_file 'test/services/module_detector_test.rb', 'app/domains/onboarding/test/services/module_detector_test.rb'
copy_file 'test/integration/onboarding_flow_test.rb', 'app/domains/onboarding/test/integration/onboarding_flow_test.rb'

# Copy fixtures
copy_file 'test/fixtures/onboarding_progresses.yml', 'app/domains/onboarding/test/fixtures/onboarding_progresses.yml'

# Create initializer if it doesn't exist
initializer_content = <<~RUBY
  # Onboarding module configuration
  Rails.application.config.autoload_paths += %W[
    \#{Rails.root}/app/domains/onboarding/app/controllers
    \#{Rails.root}/app/domains/onboarding/app/models
    \#{Rails.root}/app/domains/onboarding/app/models/concerns
    \#{Rails.root}/app/domains/onboarding/app/services
  ]
RUBY

create_file 'config/initializers/onboarding.rb', initializer_content

say 'Onboarding module installed successfully!'
say ''
say 'Next steps:'
say '  1. Run: rails db:migrate'
say '  2. Add onboarding link to your layout after user registration'
say '  3. Customize onboarding steps in app/domains/onboarding/app/views/onboarding/steps/'
say ''