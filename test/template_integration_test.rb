#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive template test script
# This script tests the Rails SaaS Starter Template end-to-end

require 'fileutils'
require 'tmpdir'

class TemplateIntegrationTest
  def initialize
    @test_dir = Dir.mktmpdir('rails_template_integration_test')
    @app_name = 'test_saas_app'
    @template_path = File.expand_path('../scaffold/template.rb', __dir__)
    @scaffold_path = File.expand_path('../scaffold', __dir__)
  end

  def run
    puts "🧪 Running Rails SaaS Starter Template Integration Tests..."
    puts "   Test directory: #{@test_dir}"
    puts "   Template: #{@template_path}"
    
    begin
      test_template_file_structure
      test_ai_module_structure
      test_cli_structure
      
      # Note: Full Rails integration test would require Rails installation
      # For now, we'll test the file structure and components
      
      puts "✅ All template integration tests passed!"
    rescue => e
      puts "❌ Template integration test failed: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    ensure
      cleanup
    end
  end

  private

  def test_template_file_structure
    raise "Template file not found: #{@template_path}" unless File.exist?(@template_path)
    
    # Check that template has required components
    content = File.read(@template_path)
    
    required_elements = [
      'gem \'pg\'',
      'gem \'devise\'',
      'gem \'sidekiq\'',
      'after_bundle do',
      'rails_command \'db:create\'',
      'git :init'
    ]
    
    required_elements.each do |element|
      raise "Template missing required element: #{element}" unless content.include?(element)
    end
    
    puts "✅ Template file structure is complete"
  end

  def test_ai_module_structure
    ai_module_path = File.join(@scaffold_path, 'lib/templates/synth/ai')
    raise "AI module directory not found: #{ai_module_path}" unless Dir.exist?(ai_module_path)
    
    required_files = ['install.rb', 'README.md']
    required_files.each do |file|
      file_path = File.join(ai_module_path, file)
      raise "AI module missing required file: #{file}" unless File.exist?(file_path)
    end
    
    # Check install.rb content
    install_content = File.read(File.join(ai_module_path, 'install.rb'))
    required_install_elements = [
      'gem \'ruby-openai\'',
      'generate :model, \'PromptTemplate\'',
      'generate :model, \'LlmOutput\'',
      'create_file \'config/initializers/ai.rb\''
    ]
    
    required_install_elements.each do |element|
      raise "AI install.rb missing: #{element}" unless install_content.include?(element)
    end
    
    puts "✅ AI module structure is complete"
  end

  def test_cli_structure
    cli_path = File.join(@scaffold_path, 'lib/synth/cli.rb')
    raise "CLI file not found: #{cli_path}" unless File.exist?(cli_path)
    
    cli_content = File.read(cli_path)
    required_cli_commands = [
      'def list',
      'def add',
      'def test',
      'def doctor'
    ]
    
    required_cli_commands.each do |command|
      raise "CLI missing command: #{command}" unless cli_content.include?(command)
    end
    
    # Check bin/synth file
    bin_synth_path = File.join(@scaffold_path, 'bin/synth')
    raise "bin/synth file not found: #{bin_synth_path}" unless File.exist?(bin_synth_path)
    
    puts "✅ CLI structure is complete"
  end

  def cleanup
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  TemplateIntegrationTest.new.run
end