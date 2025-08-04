# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "railsplan/modules_registry"

module RailsPlan
  # Manages modular template installation and management
  class ModuleManager
    attr_reader :logger, :registry

    def initialize(app_path = ".")
      @app_path = app_path
      @logger = RailsPlan.logger
      @registry = ModulesRegistry.new(app_path, logger: @logger)
    end

    # Install a module into an application
    def install_module(module_name, options = {})
      @logger.info("Installing module: #{module_name} into #{@app_path}")
      
      # Validate module exists
      unless module_available?(module_name)
        raise Error, "Module '#{module_name}' is not available"
      end
      
      # Check if already installed
      if @registry.module_installed?(module_name)
        unless options[:force]
          raise Error, "Module '#{module_name}' is already installed. Use --force to reinstall."
        end
        @logger.warn("Reinstalling module: #{module_name}")
      end
      
      # Get module template path
      template_path = module_template_path(module_name)
      
      # Validate module structure before installation
      validate_module_template(template_path, module_name)
      
      # Install the module files
      install_module_files(template_path, module_name, options)
      
      # Register in modules registry
      register_module_installation(module_name, template_path, options)
      
      @logger.info("Successfully installed module: #{module_name}")
      
      # Run post-install validation
      validate_installation(module_name) unless options[:skip_validation]
    end

    # Check if a module is available
    def module_available?(module_name)
      template_path = module_template_path(module_name)
      Dir.exist?(template_path)
    end

    # Get list of available modules
    def available_modules
      modules_template_dir = File.join(@app_path, "lib", "railsplan", "modules")
      scaffold_modules_dir = File.expand_path("../templates/modules", __dir__)
      
      modules = []
      
      # Check both locations for module templates
      [modules_template_dir, scaffold_modules_dir].each do |template_dir|
        next unless Dir.exist?(template_dir)
        
        Dir.entries(template_dir).each do |entry|
          next if entry.start_with?(".")
          module_path = File.join(template_dir, entry)
          next unless Dir.exist?(module_path)
          
          modules << entry unless modules.include?(entry)
        end
      end
      
      modules.sort
    end

    # Get list of installed modules for an application
    def installed_modules
      @registry.installed_modules
    end

    # Remove a module from an application
    def remove_module(module_name, options = {})
      @logger.info("Removing module: #{module_name} from #{@app_path}")
      
      # Check if module is installed
      unless @registry.module_installed?(module_name)
        raise Error, "Module '#{module_name}' is not installed"
      end
      
      # Run pre-removal validation
      validate_removal(module_name) unless options[:force]
      
      # Remove module files
      remove_module_files(module_name, options)
      
      # Unregister from modules registry
      @registry.unregister_module(module_name)
      
      @logger.info("Successfully removed module: #{module_name}")
    end

    # Validate a specific module installation
    def validate_module(module_name)
      require "railsplan/validator"
      validator = Validator.new(logger: @logger)
      result = validator.validate_module(module_name, @app_path)
      
      # Update validation status in registry
      status = result[:passed] ? "passed" : "failed"
      details = {
        "errors" => result[:errors],
        "warnings" => result[:warnings],
        "validated_by" => "module_manager"
      }
      
      @registry.update_validation_status(module_name, status, details)
      
      result
    end

    # Add dry-run support
    def plan_module_installation(module_name)
      @logger.info("Planning installation for module: #{module_name}")
      
      unless module_available?(module_name)
        return { success: false, error: "Module '#{module_name}' is not available" }
      end
      
      template_path = module_template_path(module_name)
      plan = {
        module_name: module_name,
        template_path: template_path,
        files_to_create: [],
        dependencies: get_module_dependencies(module_name),
        install_hooks: [],
        estimated_changes: 0
      }
      
      # Analyze what files would be created
      Dir.glob(File.join(template_path, "**/*")).each do |source_path|
        next if File.directory?(source_path)
        
        relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(template_path))
        target_path = determine_target_path(module_name, relative_path)
        
        plan[:files_to_create] << {
          source: relative_path.to_s,
          target: target_path,
          exists: File.exist?(target_path),
          action: File.exist?(target_path) ? "overwrite" : "create"
        }
      end
      
      # Check for install hooks
      install_script = File.join(template_path, "install.rb")
      plan[:install_hooks] << "install.rb" if File.exist?(install_script)
      
      plan[:estimated_changes] = plan[:files_to_create].length
      plan[:success] = true
      
      plan
    end

    private

    def module_template_path(module_name)
      # Check local modules first (in the app)
      local_path = File.join(@app_path, "lib", "railsplan", "modules", module_name)
      return local_path if Dir.exist?(local_path)
      
      # Fall back to gem templates
      File.expand_path("../templates/modules/#{module_name}", __dir__)
    end

    def validate_module_template(template_path, module_name)
      unless Dir.exist?(template_path)
        raise Error, "Module template not found: #{template_path}"
      end
      
      # Check for required files
      required_files = %w[install.rb remove.rb README.md]
      missing_files = required_files.reject { |file| File.exist?(File.join(template_path, file)) }
      
      if missing_files.any?
        @logger.warn("Module #{module_name} missing recommended files: #{missing_files.join(', ')}")
      end
    end

    def install_module_files(template_path, module_name, options)
      dry_run = options[:dry_run] || false
      
      # Copy all files from template to application
      Dir.glob(File.join(template_path, "**/*")).each do |source_path|
        next if File.directory?(source_path)
        
        # Calculate relative path from template root
        relative_path = Pathname.new(source_path).relative_path_from(
          Pathname.new(template_path)
        )
        
        # Determine target path in application
        target_path = determine_target_path(module_name, relative_path)
        
        if dry_run
          @logger.info("[DRY RUN] Would copy: #{relative_path} -> #{target_path}")
          next
        end
        
        # Create target directory if it doesn't exist
        FileUtils.mkdir_p(File.dirname(target_path))
        
        # Copy the file
        FileUtils.cp(source_path, target_path)
        
        @logger.debug("Copied: #{relative_path} -> #{target_path}")
      end
      
      # Run module-specific installation script if it exists
      install_script = File.join(template_path, "install.rb")
      if File.exist?(install_script) && !dry_run
        run_install_script(install_script, module_name, options)
      end
    end

    def determine_target_path(module_name, relative_path)
      relative_path_str = relative_path.to_s
      
      # Handle special cases for different file types
      case relative_path_str
      when /^app\//
        # App files go directly to app directory
        File.join(@app_path, relative_path_str)
      when /^config\//
        # Config files go to config directory
        File.join(@app_path, relative_path_str)
      when /^db\//
        # Database files go to db directory
        File.join(@app_path, relative_path_str)
      when /^spec\//
        # Test files go to spec directory
        File.join(@app_path, relative_path_str)
      when /^test\//
        # Test files go to test directory
        File.join(@app_path, relative_path_str)
      when /^lib\//
        # Library files go to lib directory
        File.join(@app_path, relative_path_str)
      when /^bin\//
        # Binary files go to bin directory
        File.join(@app_path, relative_path_str)
      when /^docs\//
        # Documentation files
        File.join(@app_path, relative_path_str)
      else
        # Other files go to lib/railsplan/modules/module_name/
        File.join(@app_path, "lib", "railsplan", "modules", module_name, relative_path_str)
      end
    end

    def run_install_script(script_path, module_name, options)
      @logger.info("Running install script for module: #{module_name}")
      
      # Change to app directory and run script
      Dir.chdir(@app_path) do
        # Set environment variables for the script
        ENV['RAILSPLAN_MODULE_NAME'] = module_name
        ENV['RAILSPLAN_APP_PATH'] = @app_path
        ENV['RAILSPLAN_SILENT'] = options[:silent] ? 'true' : 'false'
        
        begin
          # Load the script in the context of the application
          load script_path
        ensure
          # Clean up environment
          ENV.delete('RAILSPLAN_MODULE_NAME')
          ENV.delete('RAILSPLAN_APP_PATH')
          ENV.delete('RAILSPLAN_SILENT')
        end
      end
    rescue => e
      @logger.error("Failed to run install script for #{module_name}: #{e.message}")
      raise Error, "Module installation script failed: #{e.message}"
    end

    def register_module_installation(module_name, template_path, options)
      # Read module metadata
      version = read_module_version(template_path)
      dependencies = get_module_dependencies(module_name)
      
      metadata = {
        version: version,
        install_method: "railsplan_add",
        dependencies: dependencies,
        install_hooks_run: File.exist?(File.join(template_path, "install.rb")),
        installed_with_options: options.select { |k, v| !v.nil? },
        template_path: template_path
      }
      
      @registry.register_module(module_name, metadata)
    end

    def validate_installation(module_name)
      @logger.info("Validating installation of module: #{module_name}")
      result = validate_module(module_name)
      
      if result[:passed]
        @logger.info("✅ Module #{module_name} passed validation")
      else
        @logger.warn("⚠️  Module #{module_name} has validation issues:")
        result[:errors].each { |error| @logger.warn("  - #{error}") }
        result[:warnings].each { |warning| @logger.warn("  - #{warning}") }
      end
      
      result
    end

    def validate_removal(module_name)
      # Check for dependencies
      installed_modules.each do |installed_module|
        next if installed_module == module_name
        
        dependencies = get_module_dependencies(installed_module)
        if dependencies.include?(module_name)
          raise Error, "Cannot remove #{module_name}: required by #{installed_module}"
        end
      end
    end

    def remove_module_files(module_name, options)
      dry_run = options[:dry_run] || false
      
      # Get list of files that were installed
      template_path = module_template_path(module_name)
      
      files_removed = 0
      
      Dir.glob(File.join(template_path, "**/*")).each do |source_path|
        next if File.directory?(source_path)
        
        # Calculate relative path from template root
        relative_path = Pathname.new(source_path).relative_path_from(
          Pathname.new(template_path)
        )
        
        # Determine target path in application
        target_path = determine_target_path(module_name, relative_path)
        
        # Remove the file if it exists
        if File.exist?(target_path)
          if dry_run
            @logger.info("[DRY RUN] Would remove: #{target_path}")
          else
            FileUtils.rm(target_path)
            @logger.debug("Removed: #{target_path}")
          end
          files_removed += 1
        end
      end
      
      # Run module-specific removal script if it exists
      remove_script = File.join(template_path, "remove.rb")
      if File.exist?(remove_script) && !dry_run
        run_remove_script(remove_script, module_name, options)
      end
      
      @logger.info("Removed #{files_removed} files for module: #{module_name}")
    end

    def run_remove_script(script_path, module_name, options)
      @logger.info("Running remove script for module: #{module_name}")
      
      # Change to app directory and run script
      Dir.chdir(@app_path) do
        # Set environment variables for the script
        ENV['RAILSPLAN_MODULE_NAME'] = module_name
        ENV['RAILSPLAN_APP_PATH'] = @app_path
        ENV['RAILSPLAN_SILENT'] = options[:silent] ? 'true' : 'false'
        
        begin
          # Load the script in the context of the application
          load script_path
        ensure
          # Clean up environment
          ENV.delete('RAILSPLAN_MODULE_NAME')
          ENV.delete('RAILSPLAN_APP_PATH')
          ENV.delete('RAILSPLAN_SILENT')
        end
      end
    rescue => e
      @logger.error("Failed to run remove script for #{module_name}: #{e.message}")
      # Don't raise error for removal script failures, just warn
    end

    def read_module_version(template_path)
      version_file = File.join(template_path, "VERSION")
      if File.exist?(version_file)
        File.read(version_file).strip
      else
        "1.0.0"
      end
    end

    def get_module_dependencies(module_name)
      # This could be enhanced to read from a DEPENDENCIES file or metadata
      known_dependencies = {
        "ai" => ["openai"],
        "billing" => ["stripe"],
        "admin" => ["devise"],
        "cms" => ["carrierwave"],
        "auth" => ["devise"],
        "api" => ["grape"],
        "notifications" => ["noticed"],
        "workspace" => ["acts_as_tenant"]
      }
      
      known_dependencies[module_name] || []
    end
  end
end 