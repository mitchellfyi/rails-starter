#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for the railsplan CLI functionality

class CliTest
  def initialize
    @cli_path = File.expand_path('../scaffold/lib/railsplan/cli.rb', __dir__)
  end

  def run
    puts "🧪 Testing RailsPlan CLI functionality..."
    
    begin
      test_cli_file_exists
      test_cli_file_structure
      
      puts "✅ All CLI tests passed!"
    rescue => e
      puts "❌ CLI test failed: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  private

  def test_cli_file_exists
    raise "CLI file not found: #{@cli_path}" unless File.exist?(@cli_path)
    puts "✅ CLI file exists"
  end

  def test_cli_file_structure
    content = File.read(@cli_path)
    
    required_elements = [
      'require \'thor\'',
      'module RailsPlan',
      'class CLI < Thor',
      'desc \'list\'',
      'def list',
      'desc \'add MODULE\'',
      'def add',
      'desc \'test',
      'def test',
      'desc \'doctor\'',
      'def doctor'
    ]
    
    required_elements.each do |element|
      raise "CLI missing required element: #{element}" unless content.include?(element)
    end
    
    puts "✅ CLI file structure is complete"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  CliTest.new.run
end