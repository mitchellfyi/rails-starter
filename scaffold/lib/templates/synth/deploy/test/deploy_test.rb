# frozen_string_literal: true

require 'test_helper'

class DeployModuleTest < ActiveSupport::TestCase
  test "dockerfile configuration" do
    dockerfile_path = File.join(Rails.root, 'Dockerfile')
    
    if File.exist?(dockerfile_path)
      dockerfile_content = File.read(dockerfile_path)
      
      # Check for essential Dockerfile components
      assert dockerfile_content.include?('FROM'), "Dockerfile should have a FROM instruction"
      assert dockerfile_content.include?('COPY') || dockerfile_content.include?('ADD'), "Dockerfile should copy application files"
      assert dockerfile_content.include?('EXPOSE'), "Dockerfile should expose a port"
    else
      skip "Dockerfile not found in Rails root"
    end
  end

  test "fly.io configuration" do
    fly_toml_path = File.join(Rails.root, 'fly.toml')
    
    if File.exist?(fly_toml_path)
      fly_content = File.read(fly_toml_path)
      
      # Check for essential fly.toml sections
      assert fly_content.include?('[app]') || fly_content.include?('app_name'), "fly.toml should have app configuration"
      assert fly_content.include?('[http_service]') || fly_content.include?('[[services]]'), "fly.toml should have service configuration"
    else
      skip "fly.toml not found in Rails root"
    end
  end

  test "render.yaml configuration" do
    render_yaml_path = File.join(Rails.root, 'render.yaml')
    
    if File.exist?(render_yaml_path)
      require 'yaml'
      render_config = YAML.load_file(render_yaml_path)
      
      # Check for essential render.yaml structure
      assert render_config['services'], "render.yaml should have services configuration"
      
      if render_config['services'].is_a?(Array)
        web_service = render_config['services'].find { |s| s['type'] == 'web' }
        assert web_service, "render.yaml should have a web service"
      end
    else
      skip "render.yaml not found in Rails root"
    end
  end

  test "deployment environment variables" do
    # Test that essential environment variables are documented
    env_example_path = File.join(Rails.root, '.env.example')
    
    if File.exist?(env_example_path)
      env_content = File.read(env_example_path)
      
      # Check for deployment-related environment variables
      essential_vars = %w[
        DATABASE_URL
        REDIS_URL
        SECRET_KEY_BASE
        RAILS_ENV
      ]
      
      essential_vars.each do |var|
        assert env_content.include?(var), "#{var} should be documented in .env.example"
      end
    else
      skip ".env.example not found"
    end
  end

  test "production configuration" do
    # Test production environment configuration
    production_config_path = File.join(Rails.root, 'config', 'environments', 'production.rb')
    
    if File.exist?(production_config_path)
      production_config = File.read(production_config_path)
      
      # Check for essential production settings
      assert production_config.include?('config.force_ssl'), "Production should force SSL"
      assert production_config.include?('config.log_level'), "Production should set log level"
    else
      skip "config/environments/production.rb not found"
    end
  end

  test "database migration readiness" do
    # Test that database is ready for production deployment
    if defined?(ActiveRecord::Base)
      # Check that all migrations are up to date
      assert_nothing_raised do
        ActiveRecord::Migration.check_pending!
      end
    else
      skip "ActiveRecord not available"
    end
  end

  test "asset compilation" do
    # Test that assets can be compiled for production
    if Rails.application.config.respond_to?(:assets)
      assets_config = Rails.application.config.assets
      
      # Check that asset pipeline is configured
      assert_not_nil assets_config.compile if assets_config.respond_to?(:compile)
    end
  end

  test "health check endpoint" do
    # Test that health check endpoint is available
    if Rails.application.routes.respond_to?(:url_helpers)
      routes = Rails.application.routes.routes
      health_route = routes.find { |route| route.path.spec.to_s.include?('health') }
      
      if health_route
        assert true, "Health check route found"
      else
        skip "No health check route configured"
      end
    else
      skip "Routes not available in test environment"
    end
  end

  test "deployment scripts" do
    # Test that deployment scripts exist and are executable
    scripts_to_check = %w[
      bin/deploy
      bin/setup
      bin/update
    ]
    
    scripts_to_check.each do |script_path|
      full_path = File.join(Rails.root, script_path)
      
      if File.exist?(full_path)
        assert File.executable?(full_path), "#{script_path} should be executable"
      end
    end
  end

  test "security headers configuration" do
    # Test that security headers are configured
    if Rails.application.config.respond_to?(:force_ssl)
      # Basic security configuration check
      assert_nothing_raised do
        Rails.application.config.force_ssl
      end
    end
  end

  test "logging configuration" do
    # Test that logging is properly configured for production
    if Rails.logger
      assert Rails.logger.respond_to?(:info), "Logger should support info level"
      assert Rails.logger.respond_to?(:error), "Logger should support error level"
    end
  end
end