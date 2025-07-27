# frozen_string_literal: true

require_relative 'base_command'

module Synth
  module Commands
    # Command to display module information
    class InfoCommand < BaseCommand
      def execute(module_name)
        module_template_path = File.join(TEMPLATE_PATH, module_name)
        
        unless Dir.exist?(module_template_path)
          puts "❌ Module '#{module_name}' not found"
          return false
        end

        display_module_info(module_name, module_template_path)
        true
      end

      private

      def display_module_info(module_name, module_template_path)
        puts "📋 Module: #{module_name}"
        puts "=" * 50
        
        # Basic info
        readme_path = File.join(module_template_path, 'README.md')
        if File.exist?(readme_path)
          puts "\n📖 Description:"
          puts File.read(readme_path).lines.first(5).join
        end
        
        # Version
        version_path = File.join(module_template_path, 'VERSION')
        if File.exist?(version_path)
          puts "\n🏷️  Version: #{File.read(version_path).strip}"
        end
        
        # Installation status
        if module_installed?(module_name)
          registry = load_registry
          info = registry.dig('installed', module_name)
          puts "\n✅ Status: Installed"
          puts "   Installed version: #{info['version']}" if info['version']
          puts "   Installed at: #{info['installed_at']}" if info['installed_at']
        else
          puts "\n❌ Status: Not installed"
        end
        
        # Dependencies
        show_dependencies(module_template_path)
        
        # Files
        puts "\n📁 Files:"
        Dir.glob(File.join(module_template_path, "**/*")).each do |file|
          next if File.directory?(file)
          relative_path = Pathname.new(file).relative_path_from(Pathname.new(module_template_path))
          puts "   #{relative_path}"
        end
      end

      def show_dependencies(module_template_path)
        install_file = File.join(module_template_path, 'install.rb')
        return unless File.exist?(install_file)
        
        install_content = File.read(install_file)
        
        # Check for gem dependencies
        gem_lines = install_content.lines.select { |line| line.include?("gem ") && !line.strip.start_with?('#') }
        if gem_lines.any?
          puts "\n💎 Dependencies:"
          gem_lines.each do |line|
            gem_match = line.match(/gem\s+['"]([^'"]+)['"]/)
            if gem_match
              puts "   • #{gem_match[1]}"
            end
          end
        end
      end
    end
  end
end