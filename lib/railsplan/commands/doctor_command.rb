# frozen_string_literal: true

require_relative 'base_command'
require 'json'
require 'fileutils'

module RailsPlan
  module Commands
    # Command for system diagnostics and validation
    class DoctorCommand < BaseCommand
      def execute(options = {})
        ci_mode = options[:ci] || false
        
        if ci_mode
          puts '🏥 Running railsplan CI diagnostics...'
        else
          puts '🏥 Running system diagnostics...'
        end
        
        results = []
        results << check_ruby_version
        results << check_template_structure
        results << check_registry_integrity
        results << check_environment_variables
        results << check_pending_migrations
        results << check_module_integrity
        
        # Additional CI-specific checks
        if ci_mode
          results << check_schema_integrity
          results << check_railsplan_context
          results << check_uncommitted_railsplan_changes
        end
        
        puts "\n🏥 Diagnostics complete"
        
        failed_checks = results.count(false)
        if failed_checks > 0
          puts "❌ #{failed_checks} check(s) failed"
          puts "\n💡 Run with --verbose for detailed suggestions"
          
          # Generate CI report
          if ci_mode
            generate_ci_report(results, failed_checks)
          end
          
          false
        else
          puts "✅ All checks passed"
          
          # Generate CI report for successful run too
          if ci_mode
            generate_ci_report(results, failed_checks)
          end
          
          true
        end
      end

      private

      def check_ruby_version
        puts "Ruby version: #{RUBY_VERSION}"
        true # Ruby is running, so version is adequate
      end

      def check_template_structure
        puts "\nChecking template structure:"
        
        if File.exist?(registry_path)
          puts "✅ Module registry found"
          registry_ok = true
        else
          puts "⚠️  Module registry not found at #{registry_path}"
          registry_ok = false
        end
        
        if Dir.exist?(template_path)
          puts "✅ Module templates directory found"
          templates_ok = true
        else
          puts "⚠️  Module templates directory not found at #{template_path}"
          templates_ok = false
        end
        
        registry_ok && templates_ok
      end

      def check_registry_integrity
        return true unless File.exist?(registry_path)
        
        begin
          registry = JSON.parse(File.read(registry_path))
          puts "✅ Module registry is valid JSON"
          
          installed_count = registry.dig('installed')&.keys&.count || 0
          puts "📦 #{installed_count} module(s) registered as installed"
          true
        rescue JSON::ParserError
          puts "❌ Module registry is corrupted (invalid JSON)"
          false
        end
      end

      def check_environment_variables
        if File.exist?('.env') || File.exist?('.env.example')
          puts "✅ Environment configuration found"
          true
        else
          puts "⚠️  No .env or .env.example file found"
          puts "    Run 'bin/railsplan bootstrap' to generate environment file"
          false
        end
      end

      def check_pending_migrations
        if Dir.exist?('db/migrate')
          migration_count = Dir.glob('db/migrate/*.rb').length
          puts "📊 #{migration_count} migration file(s) found"
          
          if migration_count > 0
            puts "💡 Run 'rails db:migrate' to apply pending migrations"
          end
          true
        else
          puts "⚠️  No migrations directory found"
          false
        end
      end

      def check_module_integrity
        registry = load_registry
        installed_modules = registry['installed'] || {}
        
        integrity_ok = true
        
        installed_modules.each do |module_name, info|
          module_path = File.join('app', 'domains', module_name)
          
          if Dir.exist?(module_path)
            puts "✅ #{module_name} module files found"
          else
            puts "❌ #{module_name} module missing from app/domains/"
            integrity_ok = false
          end
        end
        
        integrity_ok
      end

      # CI-specific checks
      def check_schema_integrity
        puts "\nChecking schema integrity:"
        
        # Check if schema.rb can be loaded
        if File.exist?('db/schema.rb')
          puts "✅ Schema file found"
          
          # Try to validate schema loading in test environment
          begin
            # This is a simple syntax check, not a full load
            schema_content = File.read('db/schema.rb')
            if schema_content.include?('ActiveRecord::Schema')
              puts "✅ Schema file appears valid"
              true
            else
              puts "❌ Schema file doesn't appear to be a valid Rails schema"
              false
            end
          rescue => e
            puts "❌ Schema file validation failed: #{e.message}"
            false
          end
        else
          puts "⚠️  No schema.rb file found"
          false
        end
      end

      def check_railsplan_context
        puts "\nChecking railsplan context:"
        
        context_file = '.railsplan/context.json'
        if File.exist?(context_file)
          begin
            context = JSON.parse(File.read(context_file))
            
            # Check for required fields
            required_fields = %w[generated_at app_name models schema hash]
            missing_fields = required_fields.reject { |field| context.key?(field) }
            
            if missing_fields.empty?
              puts "✅ railsplan context is valid"
              
              # Check if context is recent (not older than 7 days)
              begin
                require 'time'
                generated_at = Time.parse(context['generated_at'])
                if Time.now - generated_at < 7 * 24 * 60 * 60 # 7 days
                  puts "✅ railsplan context is recent"
                  true
                else
                  puts "⚠️  railsplan context is older than 7 days - consider running 'railsplan index'"
                  true # Not a failure, just a warning
                end
              rescue => e
                puts "⚠️  Could not parse context timestamp: #{e.message}"
                true # Don't fail for timestamp parsing issues
              end
            else
              puts "❌ railsplan context missing required fields: #{missing_fields.join(', ')}"
              false
            end
          rescue JSON::ParserError
            puts "❌ railsplan context file is corrupted (invalid JSON)"
            false
          rescue => e
            puts "❌ Error reading railsplan context: #{e.message}"
            false
          end
        else
          puts "⚠️  No railsplan context found - run 'railsplan index' to generate"
          false
        end
      end

      def check_uncommitted_railsplan_changes
        puts "\nChecking for uncommitted railsplan changes:"
        
        railsplan_dir = '.railsplan'
        return true unless Dir.exist?(railsplan_dir)
        
        # Check if we're in a git repository
        return true unless Dir.exist?('.git')
        
        # Use git to check for uncommitted changes in .railsplan directory
        begin
          # Check for staged changes
          staged_output = `git diff --cached --name-only #{railsplan_dir}/ 2>/dev/null`.strip
          # Check for unstaged changes  
          unstaged_output = `git diff --name-only #{railsplan_dir}/ 2>/dev/null`.strip
          # Check for untracked files
          untracked_output = `git ls-files --others --exclude-standard #{railsplan_dir}/ 2>/dev/null`.strip
          
          if staged_output.empty? && unstaged_output.empty? && untracked_output.empty?
            puts "✅ No uncommitted changes in .railsplan/"
            true
          else
            puts "❌ Uncommitted changes found in .railsplan/ directory:"
            puts "  Staged: #{staged_output.split("\n").join(', ')}" unless staged_output.empty?
            puts "  Unstaged: #{unstaged_output.split("\n").join(', ')}" unless unstaged_output.empty?
            puts "  Untracked: #{untracked_output.split("\n").join(', ')}" unless untracked_output.empty?
            puts "  Please commit these changes before running CI"
            false
          end
        rescue => e
          puts "⚠️  Could not check git status: #{e.message}"
          true # Don't fail CI for git issues
        end
      end

      def generate_ci_report(results, failed_checks)
        # Ensure .railsplan directory exists
        FileUtils.mkdir_p('.railsplan')
        
        report = {
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
          total_checks: results.length,
          failed_checks: failed_checks,
          passed_checks: results.length - failed_checks,
          status: failed_checks > 0 ? 'failed' : 'passed',
          ruby_version: RUBY_VERSION,
          railsplan_version: defined?(RailsPlan::VERSION) ? RailsPlan::VERSION : 'unknown'
        }
        
        report_file = '.railsplan/doctor_report.json'
        File.write(report_file, JSON.pretty_generate(report))
        puts "📊 CI report generated: #{report_file}"
      end
    end
  end
end