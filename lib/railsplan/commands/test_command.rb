# frozen_string_literal: true

require_relative 'base_command'

module RailsPlan
  module Commands
    # Command to run tests for modules
    class TestCommand < BaseCommand
      def execute(module_name = nil)
        if module_name
          test_single_module(module_name)
        else
          test_all_modules
        end
      end

      private

      def test_single_module(module_name)
        unless module_installed?(module_name)
          puts "❌ Module '#{module_name}' is not installed"
          return false
        end
        
        # Look for module-specific tests
        test_paths = [
          "spec/domains/#{module_name}",
          "test/domains/#{module_name}",
          "spec/#{module_name}",
          "test/#{module_name}"
        ]
        
        test_path = test_paths.find { |path| Dir.exist?(path) }
        
        if test_path
          puts "🧪 Running tests for #{module_name} module..."
          if test_path.start_with?('spec/')
            system("bundle exec rspec #{test_path}")
          else
            system("bundle exec rails test #{test_path}")
          end
        else
          puts "❌ No tests found for module: #{module_name}"
          puts "Expected test directories:"
          test_paths.each { |path| puts "  - #{path}" }
          false
        end
      end

      def test_all_modules
        puts '🧪 Running full test suite...'
        
        # Try RSpec first, then fall back to Minitest
        if File.exist?('spec/rails_helper.rb')
          puts "Running RSpec test suite..."
          system('bundle exec rspec')
        elsif File.exist?('test/test_helper.rb')
          puts "Running Minitest suite..."
          system('bundle exec rails test')
        else
          puts "❌ No test framework detected"
          puts "Expected files:"
          puts "  - spec/rails_helper.rb (for RSpec)"
          puts "  - test/test_helper.rb (for Minitest)"
          false
        end
      end
    end
  end
end