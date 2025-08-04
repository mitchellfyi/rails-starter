# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module RailsPlan
  # Manages module registry for tracking installed modules and their metadata
  class ModulesRegistry
    attr_reader :registry_path, :logger

    def initialize(app_path = ".", logger: nil)
      @app_path = app_path
      @registry_path = File.join(app_path, ".railsplan", "modules.json")
      @logger = logger || RailsPlan.logger
      ensure_registry_exists
    end

    # Register a new module installation
    def register_module(module_name, metadata = {})
      @logger.info("Registering module: #{module_name}")
      
      registry = load_registry
      registry["installed"] ||= {}
      
      registry["installed"][module_name] = {
        "installed_at" => Time.now.iso8601,
        "version" => metadata[:version] || "1.0.0",
        "install_method" => metadata[:install_method] || "railsplan_add",
        "dependencies" => metadata[:dependencies] || [],
        "features" => metadata[:features] || [],
        "install_hooks_run" => metadata[:install_hooks_run] || false,
        "validation_status" => "pending"
      }.merge(metadata.transform_keys(&:to_s))
      
      save_registry(registry)
      @logger.info("Successfully registered module: #{module_name}")
    end

    # Unregister a module
    def unregister_module(module_name)
      @logger.info("Unregistering module: #{module_name}")
      
      registry = load_registry
      if registry["installed"]&.delete(module_name)
        save_registry(registry)
        @logger.info("Successfully unregistered module: #{module_name}")
        true
      else
        @logger.warn("Module #{module_name} was not found in registry")
        false
      end
    end

    # Get list of installed modules
    def installed_modules
      registry = load_registry
      registry["installed"]&.keys || []
    end

    # Get metadata for a specific module
    def module_metadata(module_name)
      registry = load_registry
      registry.dig("installed", module_name) || {}
    end

    # Update module metadata
    def update_module_metadata(module_name, updates)
      registry = load_registry
      if registry["installed"]&.key?(module_name)
        registry["installed"][module_name].merge!(updates.transform_keys(&:to_s))
        registry["installed"][module_name]["updated_at"] = Time.now.iso8601
        save_registry(registry)
        true
      else
        false
      end
    end

    # Check if a module is installed
    def module_installed?(module_name)
      installed_modules.include?(module_name)
    end

    # Get validation status for all modules
    def validation_status
      registry = load_registry
      return {} unless registry["installed"]
      
      registry["installed"].transform_values do |metadata|
        metadata["validation_status"] || "pending"
      end
    end

    # Update validation status for a module
    def update_validation_status(module_name, status, details = {})
      updates = {
        "validation_status" => status,
        "last_validated_at" => Time.now.iso8601
      }
      updates.merge!(details.transform_keys(&:to_s))
      
      update_module_metadata(module_name, updates)
    end

    # Get registry statistics
    def statistics
      registry = load_registry
      installed = registry["installed"] || {}
      
      {
        total_modules: installed.size,
        validated_modules: installed.count { |_, metadata| metadata["validation_status"] == "passed" },
        failed_modules: installed.count { |_, metadata| metadata["validation_status"] == "failed" },
        pending_modules: installed.count { |_, metadata| metadata["validation_status"] == "pending" }
      }
    end

    # Auto-register modules based on directory scan
    def auto_register_discovered_modules
      modules_dir = File.join(@app_path, "lib", "railsplan", "modules")
      return unless Dir.exist?(modules_dir)
      
      discovered = Dir.entries(modules_dir).select do |entry|
        next if entry.start_with?(".")
        Dir.exist?(File.join(modules_dir, entry))
      end
      
      newly_registered = []
      
      discovered.each do |module_name|
        unless module_installed?(module_name)
          # Auto-detect version from VERSION file
          version_file = File.join(modules_dir, module_name, "VERSION")
          version = File.exist?(version_file) ? File.read(version_file).strip : "1.0.0"
          
          register_module(module_name, {
            version: version,
            install_method: "auto_discovered",
            validation_status: "pending"
          })
          
          newly_registered << module_name
        end
      end
      
      if newly_registered.any?
        @logger.info("Auto-registered discovered modules: #{newly_registered.join(', ')}")
      end
      
      newly_registered
    end

    # Migrate from old registry format if needed
    def migrate_legacy_registry
      old_registry_path = File.join(@app_path, ".railsplanrc")
      return unless File.exist?(old_registry_path)
      
      begin
        old_config = JSON.parse(File.read(old_registry_path))
        old_modules = old_config["installed_modules"] || []
        
        registry = load_registry
        registry["installed"] ||= {}
        
        migrated = []
        old_modules.each do |module_name|
          unless registry["installed"].key?(module_name)
            old_metadata = old_config.dig("modules", module_name) || {}
            
            register_module(module_name, {
              version: old_metadata["version"] || "1.0.0",
              installed_at: old_metadata["installed_at"] || Time.now.iso8601,
              install_method: "migrated_from_railsplanrc",
              validation_status: "pending"
            })
            
            migrated << module_name
          end
        end
        
        if migrated.any?
          @logger.info("Migrated modules from .railsplanrc: #{migrated.join(', ')}")
          
          # Create backup of old file
          backup_path = "#{old_registry_path}.backup"
          FileUtils.cp(old_registry_path, backup_path)
          @logger.info("Backup of old registry created: #{backup_path}")
        end
        
        migrated
      rescue JSON::ParserError => e
        @logger.error("Failed to migrate legacy registry: #{e.message}")
        []
      end
    end

    # Validate registry integrity
    def validate_integrity
      errors = []
      
      begin
        registry = load_registry
      rescue JSON::ParserError
        errors << "Registry file is corrupted (invalid JSON)"
        return { valid: false, errors: errors }
      end
      
      # Check required structure
      unless registry.is_a?(Hash)
        errors << "Registry root is not a hash"
      end
      
      unless registry["installed"].is_a?(Hash)
        errors << "Registry 'installed' section is not a hash"
      end
      
      # Validate each module entry
      registry["installed"]&.each do |module_name, metadata|
        unless metadata.is_a?(Hash)
          errors << "Module #{module_name} metadata is not a hash"
          next
        end
        
        required_fields = %w[installed_at version install_method]
        required_fields.each do |field|
          unless metadata.key?(field)
            errors << "Module #{module_name} missing required field: #{field}"
          end
        end
        
        # Validate timestamp format
        if metadata["installed_at"]
          begin
            Time.parse(metadata["installed_at"])
          rescue ArgumentError
            errors << "Module #{module_name} has invalid timestamp format"
          end
        end
      end
      
      { valid: errors.empty?, errors: errors }
    end

    # Export registry for backup/migration
    def export
      load_registry
    end

    # Import registry from backup/migration
    def import(data, overwrite: false)
      if !overwrite && File.exist?(@registry_path)
        raise Error, "Registry already exists. Use overwrite: true to replace"
      end
      
      # Validate imported data
      unless data.is_a?(Hash) && data["installed"].is_a?(Hash)
        raise Error, "Invalid registry data format"
      end
      
      save_registry(data)
      @logger.info("Successfully imported registry with #{data['installed'].size} modules")
    end

    private

    def ensure_registry_exists
      FileUtils.mkdir_p(File.dirname(@registry_path))
      
      unless File.exist?(@registry_path)
        save_registry({
          "version" => "1.0",
          "created_at" => Time.now.iso8601,
          "installed" => {}
        })
      end
    end

    def load_registry
      return {} unless File.exist?(@registry_path)
      
      JSON.parse(File.read(@registry_path))
    rescue JSON::ParserError => e
      @logger.error("Failed to parse registry: #{e.message}")
      raise Error, "Registry file is corrupted: #{e.message}"
    end

    def save_registry(registry)
      registry["updated_at"] = Time.now.iso8601
      
      File.write(@registry_path, JSON.pretty_generate(registry))
    rescue => e
      @logger.error("Failed to save registry: #{e.message}")
      raise Error, "Failed to save registry: #{e.message}"
    end
  end
end