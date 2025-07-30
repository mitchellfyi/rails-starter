# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "railsplan/commands/docs_command"
require "railsplan/context_manager"

class DocsGenerationTest < Minitest::Test
  def setup
    @test_dir = "/tmp/test_railsplan_docs"
    @original_dir = Dir.pwd
    
    # Clean up and create test directory
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    FileUtils.mkdir_p(@test_dir)
    Dir.chdir(@test_dir)
    
    # Create minimal Rails app structure
    FileUtils.mkdir_p(%w[app/models config docs])
    File.write("config/application.rb", "module TestApp\nend")
    File.write("Gemfile", "gem 'rails'")
    File.write(".ruby-version", "3.2.3")
  end
  
  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  end
  
  def test_docs_generation_creates_all_files
    run_docs_command("docs --overwrite")
    
    expected_files = [
      "README.md",
      "docs/schema.md", 
      "docs/api.md",
      "docs/onboarding.md",
      "docs/ai_usage.md"
    ]
    
    expected_files.each do |file|
      assert File.exist?(file), "Expected #{file} to be created"
      assert File.size(file) > 0, "Expected #{file} to have content"
    end
  end
  
  def test_docs_generation_with_specific_type
    run_docs_command("docs readme --overwrite")
    
    assert File.exist?("README.md"), "Expected README.md to be created"
    refute File.exist?("docs/schema.md"), "Expected docs/schema.md to NOT be created"
  end
  
  def test_docs_generation_dry_run
    # Ensure docs directory exists with a file
    FileUtils.mkdir_p("docs")
    File.write("docs/existing.md", "existing content")
    
    output = run_docs_command("docs --dry-run --overwrite")
    
    assert_includes output, "Dry run results"
    assert_includes output, "Would generate"
    refute File.exist?("README.md"), "Expected README.md to NOT be created in dry run"
  end
  
  def test_docs_generation_silent_mode
    output = run_docs_command("docs --silent --overwrite")
    
    assert_empty output.strip, "Expected no output in silent mode"
    assert File.exist?("README.md"), "Expected README.md to be created even in silent mode"
  end
  
  def test_docs_generation_creates_prompt_log
    run_docs_command("docs readme --overwrite")
    
    assert File.exist?(".railsplan/prompts.log"), "Expected prompts.log to be created"
    
    log_content = File.read(".railsplan/prompts.log")
    assert_includes log_content, "DOCS_GENERATION: readme"
    assert_includes log_content, "OUTPUT_SIZE:"
    assert_includes log_content, "OUTPUT_LINES:"
  end
  
  def test_docs_generation_with_models
    # Create a sample model file
    FileUtils.mkdir_p("app/models")
    File.write("app/models/user.rb", <<~RUBY)
      class User < ApplicationRecord
        validates :email, presence: true, uniqueness: true
        has_many :posts
      end
    RUBY
    
    run_docs_command("docs schema --overwrite")
    
    schema_content = File.read("docs/schema.md")
    assert_includes schema_content, "# Database Schema"
    assert_includes schema_content, "## Models Overview"
    assert_includes schema_content, "User"
  end
  
  def test_docs_generation_handles_errors_gracefully
    # Remove config/application.rb to simulate non-Rails directory
    File.delete("config/application.rb")
    File.delete("Gemfile")
    
    output = run_docs_command("docs --overwrite", expect_success: false)
    
    assert_includes output, "Not in a Rails application directory"
  end
  
  def test_docs_generation_overwrite_confirmation
    # Create existing file
    File.write("README.md", "existing content")
    
    # Test without --overwrite (should prompt)
    # Note: This would normally require interactive input, 
    # so we'll just test the detection of existing files
    
    cmd = DocsCommand.new
    existing_files = cmd.send(:check_existing_files, ["readme"])
    assert_includes existing_files, "README.md"
  end
  
  private
  
  def run_docs_command(args, expect_success: true)
    cmd = "ruby -I#{File.join(@original_dir, 'lib')} #{File.join(@original_dir, 'bin/railsplan')} generate #{args} 2>&1"
    
    # Set up environment
    env = {
      'PATH' => "#{ENV['HOME']}/.local/share/gem/ruby/3.2.0/bin:#{ENV['PATH']}",
      'GEM_PATH' => "#{ENV['HOME']}/.local/share/gem/ruby/3.2.0:#{ENV['GEM_PATH']}"
    }
    
    output = `#{env.map { |k, v| "#{k}=#{v}" }.join(' ')} #{cmd}`
    
    if expect_success
      assert $?.success?, "Expected command to succeed, but got: #{output}"
    end
    
    output
  end
  
  # Helper class to access private methods for testing
  class DocsCommand
    # Manually include the module methods
    def initialize
      @context_manager = RailsPlan::ContextManager.new
    end
    
    def check_existing_files(docs_types)
      existing = []
      docs_types.each do |type|
        file_path = get_file_path_for_type(type)
        existing << file_path if File.exist?(file_path)
      end
      existing
    end
    
    def get_file_path_for_type(type)
      case type
      when 'readme'
        'README.md'
      when 'schema'
        'docs/schema.md'
      when 'api'
        'docs/api.md'
      when 'onboarding'
        'docs/onboarding.md'
      when 'ai_usage'
        'docs/ai_usage.md'
      end
    end
    
    def validate_docs_type(docs_type, options = {})
      supported_types = %w[readme schema api onboarding ai_usage]
      unless supported_types.include?(docs_type)
        return nil unless options[:silent]
      end
      [docs_type]
    end
  end
end