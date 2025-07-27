# frozen_string_literal: true

require "json"
require "fileutils"

module RailsPlan
  # Configuration management for RailsPlan
  class Config
    attr_accessor :ruby_version, :rails_version, :installed_modules, :options

    def initialize
      @ruby_version = nil
      @rails_version = nil
      @installed_modules = []
      @options = {}
    end

    # Load configuration from file
    def load_from_file(file_path)
      return unless File.exist?(file_path)
      
      begin
        data = JSON.parse(File.read(file_path))
        
        @ruby_version = data["ruby_version"]
        @rails_version = data["rails_version"]
        @installed_modules = data["installed_modules"] || []
        @options = data["options"] || {}
        
        true
      rescue JSON::ParserError => e
        RailsPlan.logger.warn("Failed to parse configuration file: #{e.message}")
        false
      end
    end

    # Save configuration to file
    def save_to_file(file_path)
      data = {
        "ruby_version" => @ruby_version,
        "rails_version" => @rails_version,
        "installed_modules" => @installed_modules,
        "options" => @options,
        "updated_at" => Time.now.iso8601
      }
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(file_path))
      
      File.write(file_path, JSON.pretty_generate(data))
      true
    rescue => e
      RailsPlan.logger.error("Failed to save configuration: #{e.message}")
      false
    end

    # Get configuration value
    def get(key, default = nil)
      @options[key.to_s] || @options[key.to_sym] || default
    end

    # Set configuration value
    def set(key, value)
      @options[key.to_s] = value
    end

    # Check if a module is installed
    def module_installed?(module_name)
      @installed_modules.include?(module_name.to_s)
    end

    # Add a module to installed modules
    def add_module(module_name)
      module_name_str = module_name.to_s
      @installed_modules << module_name_str unless @installed_modules.include?(module_name_str)
    end

    # Remove a module from installed modules
    def remove_module(module_name)
      module_name_str = module_name.to_s
      @installed_modules.delete(module_name_str)
    end

    # Get all configuration as hash
    def to_hash
      {
        "ruby_version" => @ruby_version,
        "rails_version" => @rails_version,
        "installed_modules" => @installed_modules,
        "options" => @options
      }
    end

    # Reset configuration to defaults
    def reset!
      @ruby_version = nil
      @rails_version = nil
      @installed_modules = []
      @options = {}
    end
  end
end 