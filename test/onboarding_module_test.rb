#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for the onboarding module
# This tests the onboarding module structure and basic functionality

require 'fileutils'
require 'yaml'

class OnboardingModuleTest
  def initialize
    @module_path = File.expand_path('../scaffold/lib/templates/synth/onboarding', __dir__)
    @errors = []
  end

  def run
    puts "🧪 Testing Onboarding Module..."
    
    test_module_structure
    test_installation_script
    test_model_files
    test_controller_files
    test_view_files
    test_service_files
    test_test_files
    test_documentation
    
    if @errors.empty?
      puts "✅ All onboarding module tests passed!"
      puts ""
      puts "📝 Onboarding module is ready for use"
      puts ""
      puts "Next steps:"
      puts "- Add onboarding module to generated apps with: bin/synth add onboarding"
      puts "- Run rails db:migrate after installation"
      puts "- Add onboarding links to your user registration flow"
      puts "- Customize onboarding steps for your specific needs"
      return true
    else
      puts "❌ Onboarding module tests failed:"
      @errors.each { |error| puts "   #{error}" }
      return false
    end
  end

  private

  def test_module_structure
    puts "Testing module structure..."
    
    required_files = [
      'README.md',
      'VERSION',
      'install.rb',
      'app/controllers/onboarding_controller.rb',
      'app/models/onboarding_progress.rb',
      'app/models/concerns/onboardable.rb',
      'app/services/onboarding_step_handler.rb',
      'app/services/module_detector.rb',
      'app/views/onboarding/index.html.erb',
      'app/views/onboarding/show.html.erb',
      'app/views/onboarding/complete.html.erb'
    ]
    
    required_files.each do |file|
      path = File.join(@module_path, file)
      unless File.exist?(path)
        @errors << "Missing required file: #{file}"
      end
    end
    
    puts "✅ Module structure check complete"
  end

  def test_installation_script
    puts "Testing installation script..."
    
    install_script = File.join(@module_path, 'install.rb')
    if File.exist?(install_script)
      content = File.read(install_script)
      
      required_elements = [
        'say',
        'mkdir -p',
        'copy_file',
        'OnboardingProgress',
        'onboarding',
        'route'
      ]
      
      required_elements.each do |element|
        unless content.include?(element)
          @errors << "Install script missing element: #{element}"
        end
      end
    else
      @errors << "Install script not found"
    end
    
    puts "✅ Installation script check complete"
  end

  def test_model_files
    puts "Testing model files..."
    
    model_file = File.join(@module_path, 'app/models/onboarding_progress.rb')
    if File.exist?(model_file)
      content = File.read(model_file)
      
      required_methods = [
        'belongs_to :user',
        'completed_step?',
        'mark_step_complete',
        'skip!',
        'complete?',
        'next_step',
        'progress_percentage'
      ]
      
      required_methods.each do |method|
        unless content.include?(method)
          @errors << "OnboardingProgress model missing: #{method}"
        end
      end
    else
      @errors << "OnboardingProgress model file not found"
    end
    
    concern_file = File.join(@module_path, 'app/models/concerns/onboardable.rb')
    if File.exist?(concern_file)
      content = File.read(concern_file)
      
      required_methods = [
        'onboarding_complete?',
        'onboarding_incomplete?',
        'start_onboarding!',
        'skip_onboarding!'
      ]
      
      required_methods.each do |method|
        unless content.include?(method)
          @errors << "Onboardable concern missing: #{method}"
        end
      end
    else
      @errors << "Onboardable concern file not found"
    end
    
    puts "✅ Model files check complete"
  end

  def test_controller_files
    puts "Testing controller files..."
    
    controller_file = File.join(@module_path, 'app/controllers/onboarding_controller.rb')
    if File.exist?(controller_file)
      content = File.read(controller_file)
      
      required_methods = [
        'def index',
        'def show', 
        'def update',
        'def skip',
        'def resume',
        'before_action :authenticate_user!',
        'OnboardingStepHandler'
      ]
      
      required_methods.each do |method|
        unless content.include?(method)
          @errors << "OnboardingController missing: #{method}"
        end
      end
    else
      @errors << "OnboardingController file not found"
    end
    
    puts "✅ Controller files check complete"
  end

  def test_view_files
    puts "Testing view files..."
    
    view_files = [
      'app/views/onboarding/index.html.erb',
      'app/views/onboarding/show.html.erb',
      'app/views/onboarding/complete.html.erb',
      'app/views/onboarding/partials/_progress.html.erb',
      'app/views/onboarding/partials/_navigation.html.erb',
      'app/views/onboarding/steps/_welcome.html.erb',
      'app/views/onboarding/steps/_create_workspace.html.erb',
      'app/views/onboarding/steps/_invite_colleagues.html.erb',
      'app/views/onboarding/steps/_connect_billing.html.erb',
      'app/views/onboarding/steps/_connect_ai.html.erb',
      'app/views/onboarding/steps/_explore_features.html.erb'
    ]
    
    view_files.each do |file|
      path = File.join(@module_path, file)
      unless File.exist?(path)
        @errors << "Missing view file: #{file}"
      end
    end
    
    puts "✅ View files check complete"
  end

  def test_service_files
    puts "Testing service files..."
    
    service_files = [
      'app/services/onboarding_step_handler.rb',
      'app/services/module_detector.rb'
    ]
    
    service_files.each do |file|
      path = File.join(@module_path, file)
      if File.exist?(path)
        content = File.read(path)
        
        # Check for basic class structure
        unless content.include?('class') && content.include?('def')
          @errors << "Service file #{file} missing proper class structure"
        end
      else
        @errors << "Missing service file: #{file}"
      end
    end
    
    puts "✅ Service files check complete"
  end

  def test_test_files
    puts "Testing test files..."
    
    test_files = [
      'test/models/onboarding_progress_test.rb',
      'test/controllers/onboarding_controller_test.rb',
      'test/services/onboarding_step_handler_test.rb',
      'test/services/module_detector_test.rb',
      'test/integration/onboarding_flow_test.rb',
      'test/fixtures/onboarding_progresses.yml'
    ]
    
    test_files.each do |file|
      path = File.join(@module_path, file)
      unless File.exist?(path)
        @errors << "Missing test file: #{file}"
      end
    end
    
    puts "✅ Test files check complete"
  end

  def test_documentation
    puts "Testing documentation..."
    
    readme_file = File.join(@module_path, 'README.md')
    if File.exist?(readme_file)
      content = File.read(readme_file)
      
      required_sections = [
        '# Onboarding Module',
        '## Features',
        '## Installation',
        '## Usage',
        '## Models',
        '## Routes',
        '## Testing'
      ]
      
      required_sections.each do |section|
        unless content.include?(section)
          @errors << "README missing section: #{section}"
        end
      end
    else
      @errors << "README.md file not found"
    end
    
    version_file = File.join(@module_path, 'VERSION')
    unless File.exist?(version_file) && File.read(version_file).strip.match?(/\d+\.\d+\.\d+/)
      @errors << "VERSION file missing or invalid"
    end
    
    puts "✅ Documentation check complete"
  end
end

# Run the test
test = OnboardingModuleTest.new
exit test.run ? 0 : 1