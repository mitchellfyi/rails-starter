# frozen_string_literal: true

require "open3"
require "json"

module RailsPlan
  # Manages Rails installation and version management
  class RailsManager
    attr_reader :logger

    def initialize
      @logger = RailsPlan.logger
    end

    # Check if a specific Rails version is available
    def version_available?(version)
      return true if version == "edge" || version == "main"
      
      begin
        require "rails"
        return true if Rails.version.start_with?(version)
      rescue LoadError
        # Rails not installed
      end
      
      # Check if version can be installed via gem
      gem_available?("rails", version)
    end

    # Install a specific Rails version
    def install_version(version)
      @logger.info("Installing Rails version: #{version}")
      
      if version == "edge" || version == "main"
        install_edge_rails
      else
        install_specific_rails_version(version)
      end
    end

    # Get current Rails version
    def current_version
      begin
        require "rails"
        Rails.version
      rescue LoadError
        nil
      end
    end

    # Check if Rails is installed
    def installed?
      !current_version.nil?
    end

    private

    def install_edge_rails
      @logger.info("Installing Rails edge version")
      
      # Install from GitHub main branch
      command = "gem install rails --pre --source https://rubygems.org"
      
      stdout, stderr, status = Open3.capture3(command)
      
      if status.success?
        @logger.info("Successfully installed Rails edge version")
        return true
      else
        @logger.error("Failed to install Rails edge version: #{stderr}")
        raise Error, "Failed to install Rails edge version"
      end
    end

    def install_specific_rails_version(version)
      @logger.info("Installing Rails version #{version}")
      
      command = "gem install rails -v #{version}"
      
      stdout, stderr, status = Open3.capture3(command)
      
      if status.success?
        @logger.info("Successfully installed Rails version #{version}")
        return true
      else
        @logger.error("Failed to install Rails version #{version}: #{stderr}")
        raise Error, "Failed to install Rails version #{version}"
      end
    end

    def gem_available?(gem_name, version = nil)
      command = "gem list #{gem_name}"
      command += " -v #{version}" if version
      command += " --remote"
      
      stdout, stderr, status = Open3.capture3(command)
      
      status.success? && !stdout.strip.empty?
    end
  end
end 