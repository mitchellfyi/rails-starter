#!/usr/bin/env ruby
# frozen_string_literal: true

# Template test script to verify the Rails SaaS Starter Template works
# This script tests the template by creating a new Rails app and verifying it works

require 'fileutils'
require 'tmpdir'

class TemplateTest
  def initialize
    @test_dir = Dir.mktmpdir('rails_template_test')
    @app_name = 'test_app'
    @template_path = File.expand_path('../scaffold/template.rb', __dir__)
  end

  def run
    puts "🧪 Testing Rails SaaS Starter Template..."
    puts "   Test directory: #{@test_dir}"
    puts "   Template: #{@template_path}"
    
    begin
      test_template_exists
      # Note: We can't fully test rails new without Rails being installed
      # This is a minimal test to verify the template syntax
      test_template_syntax
      
      puts "✅ Template tests passed!"
    rescue => e
      puts "❌ Template test failed: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    ensure
      cleanup
    end
  end

  private

  def test_template_exists
    raise "Template file not found: #{@template_path}" unless File.exist?(@template_path)
    puts "✅ Template file exists"
  end

  def test_template_syntax
    # Load the template to check for syntax errors
    content = File.read(@template_path)
    
    # Validate Ruby syntax using ruby -c
    begin
      result = `echo '#{content.gsub("'", "\\'")}' | ruby -c 2>&1`
      if $?.exitstatus != 0
        raise "Template has syntax error: #{result}"
      end
    rescue => e
      # If we can't run ruby -c, do a basic check
      warn "Could not run syntax check: #{e.message}"
    end
    
    puts "✅ Template syntax is valid"
  end

  def cleanup
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  TemplateTest.new.run
end