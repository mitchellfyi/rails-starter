#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration test for the synth CLI bootstrap command

require 'fileutils'
require 'tempfile'

class SynthBootstrapIntegrationTest
  def initialize
    @original_dir = Dir.pwd
    @test_dir = Dir.mktmpdir('synth_bootstrap_integration')
  end

  def run
    puts "🧪 Testing Synth CLI Bootstrap Integration..."
    
    begin
      setup_test_environment
      test_bootstrap_command_help
      test_cli_structure_integrity
      
      puts "✅ All integration tests passed!"
    rescue => e
      puts "❌ Integration test failed: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    ensure
      cleanup_test_environment
    end
  end

  private

  def setup_test_environment
    Dir.chdir(@test_dir)
    
    # Copy the CLI file to test location
    cli_source = File.join(@original_dir, 'lib', 'synth', 'cli.rb')
    FileUtils.mkdir_p('lib/synth')
    FileUtils.cp(cli_source, 'lib/synth/cli.rb')
    
    # Create minimal required directories
    FileUtils.mkdir_p(['scaffold/lib/templates', 'scaffold/config'])
    
    puts "✅ Test environment setup"
  end

  def cleanup_test_environment
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir)
  end

  def test_bootstrap_command_help
    cli_content = File.read('lib/synth/cli.rb')
    
    # Verify bootstrap command is properly defined
    unless cli_content.match(/desc\s+['"]bootstrap['"]/)
      raise "Bootstrap command desc not found"
    end
    
    unless cli_content.match(/def\s+bootstrap/)
      raise "Bootstrap command method not found"
    end
    
    # Verify command includes proper help text
    unless cli_content.include?("Interactive wizard to setup new Rails SaaS application")
      raise "Bootstrap command help text missing"
    end
    
    puts "✅ Bootstrap command properly defined with help text"
  end

  def test_cli_structure_integrity
    cli_content = File.read('lib/synth/cli.rb')
    
    # Verify all original commands are still present
    original_commands = %w[list add remove upgrade test doctor info scaffold]
    
    original_commands.each do |cmd|
      unless cli_content.match(/desc\s+['"]#{cmd}/)
        raise "Original command '#{cmd}' missing after bootstrap addition"
      end
    end
    
    # Verify new bootstrap helper methods are present
    bootstrap_methods = %w[
      collect_bootstrap_config
      prompt_for_input
      prompt_for_choice
      select_modules
      collect_api_credentials
      generate_secure_password
      setup_application
      generate_env_file
      generate_seed_data
    ]
    
    bootstrap_methods.each do |method|
      unless cli_content.include?("def #{method}")
        raise "Bootstrap helper method '#{method}' missing"
      end
    end
    
    # Verify class structure is intact
    unless cli_content.include?("class CLI < Thor")
      raise "CLI class structure damaged"
    end
    
    # Verify module structure is intact
    unless cli_content.match(/module\s+Synth/)
      raise "Synth module structure damaged"
    end
    
    puts "✅ CLI structure integrity maintained"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  SynthBootstrapIntegrationTest.new.run
end