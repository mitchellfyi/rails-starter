# frozen_string_literal: true

require_relative 'base_command'

module Synth
  module Commands
    # Command for system diagnostics and validation
    class DoctorCommand < BaseCommand
      def execute
        puts '🏥 Running system diagnostics...'
        
        results = []
        results << check_ruby_version
        results << check_template_structure
        results << check_registry_integrity
        results << check_environment_variables
        results << check_pending_migrations
        results << check_module_integrity
        
        puts "\n🏥 Diagnostics complete"
        
        failed_checks = results.count(false)
        if failed_checks > 0
          puts "❌ #{failed_checks} check(s) failed"
          puts "\n💡 Run with --verbose for detailed suggestions"
          false
        else
          puts "✅ All checks passed"
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
        
        if File.exist?(REGISTRY_PATH)
          puts "✅ Module registry found"
          registry_ok = true
        else
          puts "⚠️  Module registry not found at #{REGISTRY_PATH}"
          registry_ok = false
        end
        
        if Dir.exist?(TEMPLATE_PATH)
          puts "✅ Module templates directory found"
          templates_ok = true
        else
          puts "⚠️  Module templates directory not found at #{TEMPLATE_PATH}"
          templates_ok = false
        end
        
        registry_ok && templates_ok
      end

      def check_registry_integrity
        return true unless File.exist?(REGISTRY_PATH)
        
        begin
          registry = JSON.parse(File.read(REGISTRY_PATH))
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
          puts "    Run 'bin/synth bootstrap' to generate environment file"
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
    end
  end
end