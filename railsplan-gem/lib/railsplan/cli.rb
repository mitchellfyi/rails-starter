# frozen_string_literal: true

require "thor"
require "railsplan/generator"
require "railsplan/logger"

module RailsPlan
  # Main CLI class using Thor
  class CLI < Thor
    include Thor::Actions

    # Set the source root for templates
    def self.source_root
      File.expand_path("../templates", __dir__)
    end

    # Global options
    class_option :verbose, type: :boolean, aliases: "-v", desc: "Enable verbose output"
    class_option :force, type: :boolean, aliases: "-f", desc: "Force operation without confirmation"
    class_option :quiet, type: :boolean, aliases: "-q", desc: "Suppress output"

    # Main command to generate a new Rails application
    desc "new APP_NAME", "Generate a new Rails SaaS application"
    long_desc <<-LONGDESC
      Generate a new Rails SaaS application with AI-native features and modular architecture.
      
      This command will:
      1. Check and ensure Ruby version compatibility
      2. Install Rails if not available
      3. Generate a new Rails application with optimal defaults
      4. Apply modular templates for AI, billing, admin, and other features
      5. Set up development environment and dependencies
      
      Examples:
        railsplan new myapp                    # Generate with interactive prompts
        railsplan new myapp --ai --billing     # Generate with specific modules
        railsplan new myapp --demo             # Quick demo setup
        railsplan new myapp --guided           # Full guided setup
    LONGDESC
    option :ai, type: :boolean, desc: "Include AI module"
    option :billing, type: :boolean, desc: "Include billing module"
    option :admin, type: :boolean, desc: "Include admin panel"
    option :cms, type: :boolean, desc: "Include CMS module"
    option :demo, type: :boolean, desc: "Quick demo setup with sensible defaults"
    option :guided, type: :boolean, desc: "Full guided setup for production"
    option :ruby_version, desc: "Specify Ruby version to use"
    option :rails_version, desc: "Specify Rails version to use"
    def new(app_name)
      RailsPlan.logger.info("Starting RailsPlan application generation")
      
      generator = Generator.new(app_name, options)
      generator.generate
    end

    # Add modules to existing application
    desc "add MODULE", "Add a module to an existing Rails application"
    long_desc <<-LONGDESC
      Add a feature module to an existing Rails application.
      
      Available modules:
        ai        - AI/LLM integration with multi-provider support
        billing   - Subscription and payment processing
        admin     - Admin panel and user management
        cms       - Content management system
        auth      - Enhanced authentication and authorization
        api       - RESTful API with documentation
        notifications - Real-time notifications
        workspace - Multi-tenant workspace management
        
      Examples:
        railsplan add ai
        railsplan add billing --force
    LONGDESC
    def add(module_name)
      RailsPlan.logger.info("Adding module: #{module_name}")
      
      # TODO: Implement module addition
      say("Adding module '#{module_name}' to existing application...", :green)
      say("This feature is coming soon!", :yellow)
    end

    # List available modules
    desc "list", "List available and installed modules"
    long_desc <<-LONGDESC
      List all available modules and their installation status.
      
      Examples:
        railsplan list
        railsplan list --available
        railsplan list --installed
    LONGDESC
    option :available, type: :boolean, aliases: "-a", desc: "Show only available modules"
    option :installed, type: :boolean, aliases: "-i", desc: "Show only installed modules"
    def list
      RailsPlan.logger.info("Listing modules")
      
      # TODO: Implement module listing
      say("Available modules:", :green)
      say("  ai          - AI/LLM integration")
      say("  billing     - Subscription and payment processing")
      say("  admin       - Admin panel and user management")
      say("  cms         - Content management system")
      say("  auth        - Enhanced authentication")
      say("  api         - RESTful API with documentation")
      say("  notifications - Real-time notifications")
      say("  workspace   - Multi-tenant workspace management")
    end

    # Doctor command for validation and debugging
    desc "doctor", "Validate setup and configuration"
    long_desc <<-LONGDESC
      Run diagnostics to validate your RailsPlan setup and configuration.
      
      This command checks:
        - Ruby version compatibility
        - Rails installation
        - Required dependencies
        - Module installation status
        - Configuration files
        
      Examples:
        railsplan doctor
    LONGDESC
    def doctor
      RailsPlan.logger.info("Running doctor command")
      
      say("Running RailsPlan diagnostics...", :green)
      
      # Check Ruby version
      ruby_version = RUBY_VERSION
      ruby_manager = RailsPlan::RubyManager.new
      
      if ruby_manager.current_version_supported?
        say("✓ Ruby version: #{ruby_version} (supported)", :green)
      else
        min_version = ruby_manager.minimum_supported_version
        say("✗ Ruby version: #{ruby_version} (not supported, need >= #{min_version})", :red)
      end
      
      # Check Rails installation
      begin
        require "rails"
        rails_version = Rails.version
        say("✓ Rails version: #{rails_version}", :green)
      rescue LoadError
        say("✗ Rails not installed", :red)
      end
      
      # Check for .railsplanrc
      if File.exist?(".railsplanrc")
        say("✓ RailsPlan configuration found", :green)
      else
        say("ℹ No RailsPlan configuration found", :yellow)
      end
      
      say("Diagnostics complete!", :green)
    end

    # Rails passthrough command
    desc "rails [ARGS...]", "Pass through to Rails CLI"
    long_desc <<-LONGDESC
      Pass through to the native Rails CLI with additional RailsPlan context.
      
      Examples:
        railsplan rails server
        railsplan rails console
        railsplan rails routes
    LONGDESC
    def rails(*args)
      RailsPlan.logger.info("Passing through to Rails CLI: #{args.join(' ')}")
      
      # TODO: Implement Rails passthrough with RailsPlan context
      say("Passing through to Rails CLI...", :green)
      system("rails", *args)
    end

    # Version command
    desc "version", "Show RailsPlan version"
    def version
      say("RailsPlan #{RailsPlan::VERSION}", :green)
    end

    # Help command override
    def help
      say("RailsPlan - Global CLI for Rails SaaS Bootstrapping", :green)
      say("Version: #{RailsPlan::VERSION}", :blue)
      say("")
      super
    end

    private

    def say(message, color = nil)
      return if options[:quiet]
      
      if color
        require "pastel"
        pastel = Pastel.new
        puts pastel.send(color, message)
      else
        puts message
      end
    end
  end
end 