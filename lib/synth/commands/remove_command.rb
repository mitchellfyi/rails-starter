# frozen_string_literal: true

require_relative 'base_command'

module Synth
  module Commands
    # Command to remove modules
    class RemoveCommand < BaseCommand
      def execute(module_name, options = {})
        unless module_installed?(module_name)
          puts "❌ Module '#{module_name}' is not installed"
          show_installed_modules
          return false
        end

        unless options[:force]
          print "Are you sure you want to remove '#{module_name}'? This will delete files and may cause data loss. [y/N]: "
          confirmation = STDIN.gets.chomp.downcase
          unless confirmation == 'y' || confirmation == 'yes'
            puts "❌ Module removal cancelled"
            return false
          end
        end

        remove_module(module_name)
        true
      end

      private

      def remove_module(module_name)
        puts "🗑️  Removing #{module_name} module..."
        
        registry = load_registry
        module_info = registry.dig('installed', module_name)
        
        unless module_info
          puts "❌ Module not found in registry"
          return false
        end

        begin
          # Default removal logic
          default_module_removal(module_name)
          
          # Remove from registry
          registry['installed'].delete(module_name)
          save_registry(registry)
          
          puts "✅ Successfully removed #{module_name} module!"
          log_module_action(:remove, module_name)
          true
          
        rescue StandardError => e
          puts "❌ Error removing module: #{e.message}"
          puts e.backtrace.first(5).join("\n") if verbose
          log_module_action(:error, module_name, e.message)
          false
        end
      end

      def default_module_removal(module_name)
        # Remove from app/domains if it exists
        domains_path = File.join('app', 'domains', module_name)
        if Dir.exist?(domains_path)
          FileUtils.rm_rf(domains_path)
          log_verbose "    🗑️  Removed #{domains_path}"
        end
        
        # Remove from spec/domains if it exists
        spec_path = File.join('spec', 'domains', module_name)
        if Dir.exist?(spec_path)
          FileUtils.rm_rf(spec_path)
          log_verbose "    🗑️  Removed #{spec_path}"
        end
        
        # Remove from test/domains if it exists
        test_path = File.join('test', 'domains', module_name)
        if Dir.exist?(test_path)
          FileUtils.rm_rf(test_path)
          log_verbose "    🗑️  Removed #{test_path}"
        end
      end
    end
  end
end