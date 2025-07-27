# frozen_string_literal: true

require_relative 'base_command'

module Synth
  module Commands
    # Command to install modules
    class AddCommand < BaseCommand
      def execute(module_name, options = {})
        module_template_path = File.join(TEMPLATE_PATH, module_name)
        
        unless Dir.exist?(module_template_path)
          puts "❌ Module '#{module_name}' not found in templates"
          show_available_modules
          return false
        end

        if module_installed?(module_name) && !options[:force]
          puts "⚠️  Module '#{module_name}' is already installed. Use --force to reinstall."
          return false
        end

        install_module(module_name, module_template_path)
        true
      end

      private

      def install_module(module_name, module_template_path)
        puts "📦 Installing #{module_name} module..."
        
        install_file = File.join(module_template_path, 'install.rb')
        
        unless File.exist?(install_file)
          puts "❌ Module installer not found: #{install_file}"
          return false
        end

        begin
          # Load version info
          version_path = File.join(module_template_path, 'VERSION')
          version = File.exist?(version_path) ? File.read(version_path).strip : '1.0.0'
          
          # Create basic directories if they don't exist
          create_basic_directories
          
          # Copy module files to app/domains first
          copy_module_files(module_name, module_template_path)
          
          # Execute install.rb script with Rails generator context
          execute_install_script(install_file)
          
          # Update registry
          update_registry(module_name, {
            'version' => version,
            'installed_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
            'template_path' => module_template_path
          })
          
          puts "✅ Successfully installed #{module_name} module!"
          log_module_action(:install, module_name, version)
          true
          
        rescue StandardError => e
          puts "❌ Error installing module: #{e.message}"
          puts e.backtrace.first(5).join("\n") if verbose
          log_module_action(:error, module_name, e.message)
          false
        end
      end

      def execute_install_script(install_file)
        # Load and execute the installer in the context of a Rails generator
        # This allows the install scripts to use Rails generator methods like add_gem, after_bundle, etc.
        require 'rails/generators'
        require 'rails/generators/base'
        
        generator_class = Class.new(Rails::Generators::Base) do
          include Rails::Generators::Actions
          
          def self.source_root
            Rails.root
          end
        end
        
        generator = generator_class.new
        generator.instance_eval(File.read(install_file))
      end

      def create_basic_directories
        FileUtils.mkdir_p('app/domains')
        FileUtils.mkdir_p('log')
      end

      def copy_module_files(module_name, module_template_path)
        target_dir = File.join('app', 'domains', module_name)
        FileUtils.mkdir_p(target_dir)
        
        # Copy all files except installer scripts
        Dir.glob(File.join(module_template_path, "**/*")).each do |file|
          next if File.directory?(file)
          next if ['install.rb', 'remove.rb', 'VERSION'].include?(File.basename(file))
          
          relative_path = Pathname.new(file).relative_path_from(Pathname.new(module_template_path))
          target_file = File.join(target_dir, relative_path)
          
          FileUtils.mkdir_p(File.dirname(target_file))
          FileUtils.cp(file, target_file)
          log_verbose "  ✅ Copied #{relative_path}"
        end
      end
    end
  end
end