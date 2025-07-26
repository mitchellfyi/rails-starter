#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to validate the deploy module functionality
# Run with: ruby test/deploy_module_test.rb

require 'minitest/autorun'
require 'yaml'
require 'fileutils'

class DeployModuleTest < Minitest::Test
  def setup
    @template_path = File.expand_path('../scaffold/lib/templates/synth/deploy', __dir__)
  end

  def test_deploy_module_exists
    assert Dir.exist?(@template_path), "Deploy module directory should exist"
  end

  def test_install_script_exists
    install_path = File.join(@template_path, 'install.rb')
    assert File.exist?(install_path), "Install script should exist"
    
    content = File.read(install_path)
    assert_includes content, "synth_deploy", "Install script should use synth_deploy status"
    assert_includes content, "Deploy module", "Install script should mention deploy module"
  end

  def test_fly_config_template_exists
    fly_config = File.join(@template_path, 'fly.toml.tt')
    assert File.exist?(fly_config), "Fly.io configuration template should exist"
    
    content = File.read(fly_config)
    assert_includes content, "<%= app_name %>", "Fly config should have app_name template variable"
    assert_includes content, "internal_port = 3000", "Fly config should configure port 3000"
  end

  def test_render_config_template_exists
    render_config = File.join(@template_path, 'render.yaml.tt')
    assert File.exist?(render_config), "Render configuration template should exist"
    
    content = File.read(render_config)
    assert_includes content, "<%= app_name %>", "Render config should have app_name template variable"
    assert_includes content, "type: web", "Render config should define web service"
  end

  def test_kamal_config_template_exists
    kamal_config = File.join(@template_path, 'config/deploy.yml.tt')
    assert File.exist?(kamal_config), "Kamal configuration template should exist"
    
    content = File.read(kamal_config)
    assert_includes content, "<%= app_name %>", "Kamal config should have app_name template variable"
    assert_includes content, "service:", "Kamal config should define service"
  end

  def test_dockerfile_exists
    dockerfile = File.join(@template_path, 'Dockerfile')
    assert File.exist?(dockerfile), "Dockerfile should exist"
    
    content = File.read(dockerfile)
    assert_includes content, "FROM ruby:", "Dockerfile should use Ruby base image"
    assert_includes content, "EXPOSE 3000", "Dockerfile should expose port 3000"
  end

  def test_dockerignore_exists
    dockerignore = File.join(@template_path, '.dockerignore')
    assert File.exist?(dockerignore), ".dockerignore should exist"
    
    content = File.read(dockerignore)
    assert_includes content, ".git", ".dockerignore should exclude .git"
    assert_includes content, "node_modules/", ".dockerignore should exclude node_modules"
  end

  def test_env_template_exists
    env_template = File.join(@template_path, '.env.production.example')
    assert File.exist?(env_template), "Environment template should exist"
    
    content = File.read(env_template)
    assert_includes content, "DATABASE_URL=", "Environment template should include DATABASE_URL"
    assert_includes content, "REDIS_URL=", "Environment template should include REDIS_URL"
    assert_includes content, "SECRET_KEY_BASE=", "Environment template should include SECRET_KEY_BASE"
  end

  def test_github_workflows_exist
    fly_workflow = File.join(@template_path, '.github/workflows/fly-deploy.yml')
    kamal_workflow = File.join(@template_path, '.github/workflows/kamal-deploy.yml')
    
    assert File.exist?(fly_workflow), "Fly deployment workflow should exist"
    assert File.exist?(kamal_workflow), "Kamal deployment workflow should exist"
  end

  def test_yaml_files_are_valid
    yaml_files = Dir.glob(File.join(@template_path, '**/*.yml')) + 
                 Dir.glob(File.join(@template_path, '**/*.yaml'))
    
    yaml_files.each do |file|
      content = File.read(file)
      # Skip template files with ERB syntax
      next if content.include?('<%= app_name %>')
      
      begin
        YAML.safe_load(content)
      rescue Psych::SyntaxError => e
        flunk "Invalid YAML in #{file}: #{e.message}"
      end
    end
  end

  def test_readme_exists
    readme = File.join(@template_path, 'README.md')
    assert File.exist?(readme), "Deploy module README should exist"
    
    content = File.read(readme)
    assert_includes content, "Deploy Module", "README should have title"
    assert_includes content, "Fly.io", "README should mention Fly.io"
    assert_includes content, "Render", "README should mention Render"
    assert_includes content, "Kamal", "README should mention Kamal"
  end
end