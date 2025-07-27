# frozen_string_literal: true

# DemoFeature module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the demo_feature module.

say_status :demo_feature, "Installing DemoFeature module"

# Add any required gems to the application's Gemfile
# add_gem 'example_gem', '~> 1.0'

# Run after bundle install to set up the module
after_bundle do
  # Create domain-specific directories
  run 'mkdir -p app/controllers app/models app/views app/services'
  run 'mkdir -p test/models test/controllers test/services'
  run 'mkdir -p spec/models spec/controllers spec/requests spec/services'
  
  # Create initializer for module configuration
  initializer 'demo_feature.rb', <<~'INIT_RUBY'
    # DemoFeature module configuration
    Rails.application.config.demo_feature = ActiveSupport::OrderedOptions.new
    
    # Enable the module by default
    Rails.application.config.demo_feature.enabled = true
    
    # Add your configuration options here
    # Rails.application.config.demo_feature.option_name = 'default_value'
  INIT_RUBY

  # Copy module files to the application
  demo_feature_source = File.join(__dir__, 'app')
  if Dir.exist?(demo_feature_source)
    # Copy controllers
    Dir.glob(File.join(demo_feature_source, 'controllers', '**', '*.rb')).each do |file|
      relative_path = Pathname.new(file).relative_path_from(Pathname.new(demo_feature_source))
      copy_file file, File.join('app', relative_path)
    end
    
    # Copy models
    Dir.glob(File.join(demo_feature_source, 'models', '**', '*.rb')).each do |file|
      relative_path = Pathname.new(file).relative_path_from(Pathname.new(demo_feature_source))
      copy_file file, File.join('app', relative_path)
    end
    
    # Copy views
    Dir.glob(File.join(demo_feature_source, 'views', '**', '*')).each do |file|
      next if File.directory?(file)
      relative_path = Pathname.new(file).relative_path_from(Pathname.new(demo_feature_source))
      copy_file file, File.join('app', relative_path)
    end
    
    # Copy services
    Dir.glob(File.join(demo_feature_source, 'services', '**', '*.rb')).each do |file|
      relative_path = Pathname.new(file).relative_path_from(Pathname.new(demo_feature_source))
      copy_file file, File.join('app', relative_path)
    end
  end

  # Copy migrations
  migration_source = File.join(__dir__, 'db', 'migrate')
  if Dir.exist?(migration_source)
    Dir.glob(File.join(migration_source, '*.rb')).each do |migration_file|
      migration_name = File.basename(migration_file)
      target_name = "#{Time.now.strftime('%Y%m%d%H%M%S')}_#{migration_name}"
      copy_file migration_file, File.join('db', 'migrate', target_name)
    end
  end

  # Add routes if routes file exists
  routes_file = File.join(__dir__, 'config', 'routes.rb')
  if File.exist?(routes_file)
    route_content = File.read(routes_file)
    # Add the routes to the main routes file
    # You may need to customize this based on your routing needs
    insert_into_file 'config/routes.rb', route_content, after: "Rails.application.routes.draw do\n"
  end

  # Run any additional setup commands
  # run 'rails db:migrate'
  # run 'yarn add package-name'

  say_status :demo_feature, "✅ DemoFeature module installed successfully!"
  say_status :demo_feature, "📝 Configure the module in config/initializers/demo_feature.rb"
  say_status :demo_feature, "🗄️  Run 'rails db:migrate' to apply database changes"
  say_status :demo_feature, "📖 See the module documentation in app/domains/demo_feature/README.md"
end
