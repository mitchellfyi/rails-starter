# frozen_string_literal: true

require "open3"
require "json"

module RailsPlan
  # Manages Ruby version detection, installation, and compatibility
  class RubyManager
    attr_reader :logger

    def initialize
      @logger = RailsPlan.logger
    end

    # Check if a specific Ruby version is available and compatible
    def version_compatible?(version)
      return true if version == RUBY_VERSION
      
      # Check if version is installed via version managers
      return true if rbenv_version_installed?(version)
      return true if rvm_version_installed?(version)
      return true if asdf_version_installed?(version)
      
      false
    end

    # Check if current Ruby version is supported
    def current_version_supported?
      supported_versions = ["3.4.2", "3.4.1", "3.4.0", "3.3.0"]
      
      # Check if current version matches any supported version pattern
      supported_versions.any? do |supported|
        RUBY_VERSION.start_with?(supported.split('.')[0..1].join('.'))
      end
    end

    # Get minimum supported Ruby version
    def minimum_supported_version
      "3.3.0"
    end

    # Ensure a specific Ruby version is available
    def ensure_version(version)
      return if version == RUBY_VERSION
      
      @logger.info("Ensuring Ruby version #{version} is available")
      
      # Try to install via version managers
      if install_via_rbenv(version)
        return
      elsif install_via_rvm(version)
        return
      elsif install_via_asdf(version)
        return
      else
        raise Error, "Could not install Ruby version #{version}. Please install it manually."
      end
    end

    # Suggest a compatible Ruby version
    def suggest_ruby_version
      # Prefer Rails-compatible versions (3.3.0+ only)
      preferred_versions = ["3.4.2", "3.4.1", "3.4.0", "3.3.0"]
      
      preferred_versions.each do |version|
        return version if version_compatible?(version)
      end
      
      # Fallback to current version
      RUBY_VERSION
    end

    # Get list of available Ruby versions
    def available_versions
      versions = []
      
      # Check rbenv
      versions.concat(rbenv_versions) if rbenv_available?
      
      # Check rvm
      versions.concat(rvm_versions) if rvm_available?
      
      # Check asdf
      versions.concat(asdf_versions) if asdf_available?
      
      versions.uniq.sort
    end

    private

    def rbenv_available?
      system("which rbenv > /dev/null 2>&1")
    end

    def rvm_available?
      system("which rvm > /dev/null 2>&1")
    end

    def asdf_available?
      system("which asdf > /dev/null 2>&1")
    end

    def rbenv_version_installed?(version)
      return false unless rbenv_available?
      
      stdout, stderr, status = Open3.capture3("rbenv versions --bare")
      return false unless status.success?
      
      stdout.lines.map(&:strip).include?(version)
    end

    def rvm_version_installed?(version)
      return false unless rvm_available?
      
      stdout, stderr, status = Open3.capture3("rvm list --bare")
      return false unless status.success?
      
      stdout.lines.map(&:strip).any? { |line| line.include?(version) }
    end

    def asdf_version_installed?(version)
      return false unless asdf_available?
      
      stdout, stderr, status = Open3.capture3("asdf list ruby")
      return false unless status.success?
      
      stdout.lines.map(&:strip).include?(version)
    end

    def install_via_rbenv(version)
      return false unless rbenv_available?
      
      @logger.info("Installing Ruby #{version} via rbenv")
      
      stdout, stderr, status = Open3.capture3("rbenv install #{version}")
      
      if status.success?
        @logger.info("Successfully installed Ruby #{version} via rbenv")
        return true
      else
        @logger.warn("Failed to install Ruby #{version} via rbenv: #{stderr}")
        return false
      end
    end

    def install_via_rvm(version)
      return false unless rvm_available?
      
      @logger.info("Installing Ruby #{version} via rvm")
      
      stdout, stderr, status = Open3.capture3("rvm install #{version}")
      
      if status.success?
        @logger.info("Successfully installed Ruby #{version} via rvm")
        return true
      else
        @logger.warn("Failed to install Ruby #{version} via rvm: #{stderr}")
        return false
      end
    end

    def install_via_asdf(version)
      return false unless asdf_available?
      
      @logger.info("Installing Ruby #{version} via asdf")
      
      stdout, stderr, status = Open3.capture3("asdf install ruby #{version}")
      
      if status.success?
        @logger.info("Successfully installed Ruby #{version} via asdf")
        return true
      else
        @logger.warn("Failed to install Ruby #{version} via asdf: #{stderr}")
        return false
      end
    end

    def rbenv_versions
      return [] unless rbenv_available?
      
      stdout, stderr, status = Open3.capture3("rbenv versions --bare")
      return [] unless status.success?
      
      stdout.lines.map(&:strip)
    end

    def rvm_versions
      return [] unless rvm_available?
      
      stdout, stderr, status = Open3.capture3("rvm list --bare")
      return [] unless status.success?
      
      stdout.lines.map(&:strip).map { |line| line.split[0] }.compact
    end

    def asdf_versions
      return [] unless asdf_available?
      
      stdout, stderr, status = Open3.capture3("asdf list ruby")
      return [] unless status.success?
      
      stdout.lines.map(&:strip)
    end
  end
end 