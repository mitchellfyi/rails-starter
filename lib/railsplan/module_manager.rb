# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

module RailsPlan
  # Manages modular template installation and management
  class ModuleManager
    attr_reader :logger

    def initialize
      @logger = RailsPlan.logger
    end

    # Install a module into an application
    def install_module(module_name, app_path, options = {})
      @logger.info("Installing module: #{module_name} into #{app_path}")
      
      # Validate module exists
      unless module_available?(module_name)
        raise Error, "Module '#{module_name}' is not available"
      end
      
      # Get module template path
      template_path = module_template_path(module_name)
      
      # Install the module
      install_module_files(template_path, app_path, module_name, options)
      
      # Update module registry
      update_module_registry(app_path, module_name)
      
      @logger.info("Successfully installed module: #{module_name}")
    end

    # Check if a module is available
    def module_available?(module_name)
      template_path = module_template_path(module_name)
      Dir.exist?(template_path)
    end

    # Get list of available modules
    def available_modules
      template_dir = File.expand_path("../templates/modules", __dir__)
      return [] unless Dir.exist?(template_dir)
      
      Dir.entries(template_dir).select do |entry|
        next if entry.start_with?(".")
        Dir.exist?(File.join(template_dir, entry))
      end
    end

    # Get list of installed modules for an application
    def installed_modules(app_path)
      registry_path = File.join(app_path, ".railsplanrc")
      return [] unless File.exist?(registry_path)
      
      begin
        config = JSON.parse(File.read(registry_path))
        config["installed_modules"] || []
      rescue JSON::ParserError
        []
      end
    end

    # Remove a module from an application
    def remove_module(module_name, app_path, options = {})
      @logger.info("Removing module: #{module_name} from #{app_path}")
      
      # Check if module is installed
      unless installed_modules(app_path).include?(module_name)
        raise Error, "Module '#{module_name}' is not installed"
      end
      
      # Remove module files
      remove_module_files(app_path, module_name, options)
      
      # Update module registry
      remove_from_registry(app_path, module_name)
      
      @logger.info("Successfully removed module: #{module_name}")
    end

    private

    def module_template_path(module_name)
      File.expand_path("../templates/modules/#{module_name}", __dir__)
    end

    def install_module_files(template_path, app_path, module_name, options)
      # Copy all files from template to application
      Dir.glob(File.join(template_path, "**/*")).each do |source_path|
        next if File.directory?(source_path)
        
        # Calculate relative path from template root
        relative_path = Pathname.new(source_path).relative_path_from(
          Pathname.new(template_path)
        )
        
        # Determine target path in application
        target_path = determine_target_path(app_path, module_name, relative_path)
        
        # Create target directory if it doesn't exist
        FileUtils.mkdir_p(File.dirname(target_path))
        
        # Copy the file
        FileUtils.cp(source_path, target_path)
        
        @logger.debug("Copied: #{relative_path} -> #{target_path}")
      end
      
      # Run module-specific installation script if it exists
      install_script = File.join(template_path, "install.rb")
      if File.exist?(install_script)
        run_install_script(install_script, app_path, module_name, options)
      end
    end

    def determine_target_path(app_path, module_name, relative_path)
      relative_path_str = relative_path.to_s
      
      # Handle special cases for different file types
      case relative_path_str
      when /^app\//
        # App files go directly to app directory
        File.join(app_path, relative_path_str)
      when /^config\//
        # Config files go to config directory
        File.join(app_path, relative_path_str)
      when /^db\//
        # Database files go to db directory
        File.join(app_path, relative_path_str)
      when /^spec\//
        # Test files go to spec directory
        File.join(app_path, relative_path_str)
      when /^test\//
        # Test files go to test directory
        File.join(app_path, relative_path_str)
      when /^lib\//
        # Library files go to lib directory
        File.join(app_path, relative_path_str)
      when /^bin\//
        # Binary files go to bin directory
        File.join(app_path, relative_path_str)
      else
        # Other files go to app/domains/module_name/
        File.join(app_path, "app", "domains", module_name, relative_path_str)
      end
    end

    def run_install_script(script_path, app_path, module_name, options)
      @logger.info("Running install script for module: #{module_name}")
      
      # Change to app directory and run script
      Dir.chdir(app_path) do
        # Load the script in the context of the application
        load script_path
      end
    rescue => e
      @logger.error("Failed to run install script for #{module_name}: #{e.message}")
      raise Error, "Module installation script failed: #{e.message}"
    end

    def update_module_registry(app_path, module_name)
      registry_path = File.join(app_path, ".railsplanrc")
      
      # Load existing config or create new one
      config = if File.exist?(registry_path)
        JSON.parse(File.read(registry_path))
      else
        {}
      end
      
      # Update installed modules
      config["installed_modules"] ||= []
      config["installed_modules"] << module_name unless config["installed_modules"].include?(module_name)
      
      # Add module metadata
      config["modules"] ||= {}
              config["modules"][module_name] = {
          "installed_at" => Time.now.iso8601,
          "version" => module_version(module_name)
        }
      
      # Write updated config
      File.write(registry_path, JSON.pretty_generate(config))
    end

    def remove_from_registry(app_path, module_name)
      registry_path = File.join(app_path, ".railsplanrc")
      return unless File.exist?(registry_path)
      
      begin
        config = JSON.parse(File.read(registry_path))
        
        # Remove from installed modules
        config["installed_modules"]&.delete(module_name)
        
        # Remove module metadata
        config["modules"]&.delete(module_name)
        
        # Write updated config
        File.write(registry_path, JSON.pretty_generate(config))
      rescue JSON::ParserError
        @logger.warn("Failed to parse module registry, skipping registry update")
      end
    end

    def remove_module_files(app_path, module_name, options)
      # Get list of files that were installed
      template_path = module_template_path(module_name)
      
      Dir.glob(File.join(template_path, "**/*")).each do |source_path|
        next if File.directory?(source_path)
        
        # Calculate relative path from template root
        relative_path = Pathname.new(source_path).relative_path_from(
          Pathname.new(template_path)
        )
        
        # Determine target path in application
        target_path = determine_target_path(app_path, module_name, relative_path)
        
        # Remove the file if it exists
        if File.exist?(target_path)
          FileUtils.rm(target_path)
          @logger.debug("Removed: #{target_path}")
        end
      end
      
      # Run module-specific removal script if it exists
      remove_script = File.join(template_path, "remove.rb")
      if File.exist?(remove_script)
        run_remove_script(remove_script, app_path, module_name, options)
      end
    end

    def run_remove_script(script_path, app_path, module_name, options)
      @logger.info("Running remove script for module: #{module_name}")
      
      # Change to app directory and run script
      Dir.chdir(app_path) do
        # Load the script in the context of the application
        load script_path
      end
    rescue => e
      @logger.error("Failed to run remove script for #{module_name}: #{e.message}")
      # Don't raise error for removal script failures
    end

    def module_version(module_name)
      version_file = File.join(module_template_path(module_name), "VERSION")
      if File.exist?(version_file)
        File.read(version_file).strip
      else
        "1.0.0"
      end
    end
  end
end 