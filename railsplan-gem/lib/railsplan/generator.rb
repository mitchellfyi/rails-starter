# frozen_string_literal: true

require "fileutils"
require "pathname"
require "railsplan/ruby_manager"
require "railsplan/rails_manager"
require "railsplan/app_generator"
require "railsplan/module_manager"
require "railsplan/logger"

module RailsPlan
  # Main generator class that orchestrates the Rails application generation
  class Generator
    attr_reader :app_name, :options, :config

    def initialize(app_name, options = {})
      @app_name = app_name
      @options = options
      @config = RailsPlan.config
      @logger = RailsPlan.logger
      
      # Initialize managers
      @ruby_manager = RubyManager.new
      @rails_manager = RailsManager.new
      @app_generator = AppGenerator.new(app_name, options)
      @module_manager = ModuleManager.new
    end

    def generate
      @logger.info("Starting RailsPlan generation for: #{app_name}")
      
      begin
        # Step 1: Validate and prepare environment
        validate_environment
        
        # Step 2: Ensure Ruby version compatibility
        ensure_ruby_version
        
        # Step 3: Ensure Rails is available
        ensure_rails_available
        
        # Step 4: Generate the Rails application
        generate_rails_app
        
        # Step 5: Apply modular templates
        apply_modular_templates
        
        # Step 6: Post-process the application
        post_process_app
        
        # Step 7: Finalize setup
        finalize_setup
        
        @logger.info("RailsPlan generation completed successfully")
        display_success_message
        
      rescue => e
        @logger.error("Generation failed: #{e.message}")
        display_error_message(e)
        raise
      end
    end

    private

    def validate_environment
      @logger.info("Validating environment")
      
      # Check if app name is valid
      unless valid_app_name?
        raise Error, "Invalid application name: #{app_name}. Use only letters, numbers, and underscores."
      end
      
      # Check if directory already exists
      if Dir.exist?(app_name)
        if options[:force]
          @logger.info("Removing existing directory: #{app_name}")
          FileUtils.rm_rf(app_name)
        else
          raise Error, "Directory '#{app_name}' already exists. Use --force to overwrite."
        end
      end
      
      # Check if we're in a good location to create the app
      unless can_create_app_here?
        raise Error, "Cannot create application here. Check permissions and available space."
      end
    end

    def ensure_ruby_version
      @logger.info("Ensuring Ruby version compatibility")
      
      # First check if current Ruby version is supported
      unless @ruby_manager.current_version_supported?
        min_version = @ruby_manager.minimum_supported_version
        raise Error, "Ruby #{RUBY_VERSION} is not supported. Please use Ruby >= #{min_version}"
      end
      
      target_version = options[:ruby_version] || detect_ruby_version
      
      unless @ruby_manager.version_compatible?(target_version)
        @logger.warn("Ruby version #{target_version} not found or incompatible")
        
        if options[:guided]
          target_version = prompt_for_ruby_version
        else
          target_version = @ruby_manager.suggest_ruby_version
        end
      end
      
      @ruby_manager.ensure_version(target_version)
      @config.ruby_version = target_version
    end

    def ensure_rails_available
      @logger.info("Ensuring Rails is available")
      
      target_version = options[:rails_version] || "edge"
      
      unless @rails_manager.version_available?(target_version)
        @logger.info("Installing Rails #{target_version}")
        @rails_manager.install_version(target_version)
      end
      
      @config.rails_version = target_version
    end

    def generate_rails_app
      @logger.info("Generating Rails application")
      
      @app_generator.generate do |step, message|
        @logger.info("Rails generation: #{step} - #{message}")
      end
    end

    def apply_modular_templates
      @logger.info("Applying modular templates")
      
      # Determine which modules to install
      modules_to_install = determine_modules_to_install
      
      modules_to_install.each do |module_name|
        @logger.info("Installing module: #{module_name}")
        @module_manager.install_module(module_name, app_name, options)
      end
      
      @config.installed_modules = modules_to_install
    end

    def post_process_app
      @logger.info("Post-processing application")
      
      Dir.chdir(app_name) do
        # Apply base templates
        apply_base_templates
        
        # Set up development environment
        setup_development_environment
        
        # Install dependencies
        install_dependencies
        
        # Set up database
        setup_database
      end
    end

    def finalize_setup
      @logger.info("Finalizing setup")
      
      Dir.chdir(app_name) do
        # Create RailsPlan configuration
        create_railsplan_config
        
        # Set up git repository
        setup_git_repository
        
        # Create initial commit
        create_initial_commit
      end
    end

    def determine_modules_to_install
      modules = []
      
      # Check command line options
      modules << "ai" if options[:ai]
      modules << "billing" if options[:billing]
      modules << "admin" if options[:admin]
      modules << "cms" if options[:cms]
      
      # If no modules specified, prompt user
      if modules.empty?
        if options[:demo]
          modules = ["ai", "billing", "admin"]
        elsif options[:guided]
          modules = prompt_for_modules
        else
          modules = prompt_for_modules
        end
      end
      
      modules
    end

    def apply_base_templates
      @logger.info("Applying base templates")
      
      # Copy base template files
      template_files = Dir.glob(File.expand_path("../templates/base/**/*", __dir__))
      
      template_files.each do |template_file|
        relative_path = Pathname.new(template_file).relative_path_from(
          Pathname.new(File.expand_path("../templates/base", __dir__))
        )
        
        target_path = relative_path.to_s
        
        if File.directory?(template_file)
          FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
        else
          FileUtils.mkdir_p(File.dirname(target_path))
          FileUtils.cp(template_file, target_path)
        end
      end
    end

    def setup_development_environment
      @logger.info("Setting up development environment")
      
      # Create .env file
      create_env_file
      
      # Set up binstubs
      setup_binstubs
      
      # Create bin/setup script
      create_setup_script
    end

    def install_dependencies
      @logger.info("Installing dependencies")
      
      system("bundle install") or raise Error, "Failed to install dependencies"
    end

    def setup_database
      @logger.info("Setting up database")
      
      system("rails db:create") or raise Error, "Failed to create database"
      system("rails db:migrate") or raise Error, "Failed to run migrations"
      system("rails db:seed") or raise Error, "Failed to seed database"
    end

    def create_railsplan_config
      @logger.info("Creating RailsPlan configuration")
      
              config_data = {
          version: RailsPlan::VERSION,
          generated_at: Time.now.iso8601,
          ruby_version: @config.ruby_version,
          rails_version: @config.rails_version,
          installed_modules: @config.installed_modules,
          options: options
        }
      
      File.write(".railsplanrc", JSON.pretty_generate(config_data))
    end

    def setup_git_repository
      @logger.info("Setting up git repository")
      
      return if Dir.exist?(".git")
      
      system("git init") or raise Error, "Failed to initialize git repository"
      
      # Create .gitignore if it doesn't exist
      unless File.exist?(".gitignore")
        FileUtils.cp(File.expand_path("../templates/base/.gitignore", __dir__), ".gitignore")
      end
    end

    def create_initial_commit
      @logger.info("Creating initial commit")
      
      system("git add .") or raise Error, "Failed to stage files"
      system("git commit -m 'Initial commit: RailsPlan generated application'") or 
        raise Error, "Failed to create initial commit"
    end

    def valid_app_name?
      app_name.match?(/^[a-zA-Z][a-zA-Z0-9_]*$/)
    end

    def can_create_app_here?
      # Check if we have write permissions
      File.writable?(Dir.pwd) &&
      # Check if we have enough space (rough estimate)
      (File.stat(Dir.pwd).blocks * 512) > 100_000_000 # 100MB
    end

    def detect_ruby_version
      # Try to read from .ruby-version file
      if File.exist?(".ruby-version")
        File.read(".ruby-version").strip
      else
        RUBY_VERSION
      end
    end

    def prompt_for_ruby_version
      # TODO: Implement interactive Ruby version selection
      @ruby_manager.suggest_ruby_version
    end

    def prompt_for_modules
      # TODO: Implement interactive module selection
      ["ai", "billing", "admin"]
    end

    def create_env_file
      env_template = File.expand_path("../templates/base/.env.example", __dir__)
      FileUtils.cp(env_template, ".env") if File.exist?(env_template)
    end

    def setup_binstubs
      system("bundle binstubs rails") or raise Error, "Failed to create binstubs"
    end

    def create_setup_script
      setup_script = <<~SCRIPT
        #!/usr/bin/env bash
        set -euo pipefail
        IFS=$'\\n\\t'

        # Exit on any error
        set -e

        # Colors for output
        RED='\\033[0;31m'
        GREEN='\\033[0;32m'
        YELLOW='\\033[1;33m'
        NC='\\033[0m' # No Color

        echo -e "${GREEN}Setting up #{app_name}...${NC}"

        # Install dependencies
        echo -e "${YELLOW}Installing dependencies...${NC}"
        bundle install

        # Set up database
        echo -e "${YELLOW}Setting up database...${NC}"
        rails db:create
        rails db:migrate
        rails db:seed

        # Set up environment
        echo -e "${YELLOW}Setting up environment...${NC}"
        cp .env.example .env if [ -f .env.example ] && [ ! -f .env ]

        echo -e "${GREEN}Setup complete!${NC}"
        echo -e "${GREEN}Run 'rails server' to start the development server${NC}"
      SCRIPT
      
      File.write("bin/setup", setup_script)
      FileUtils.chmod("+x", "bin/setup")
    end

    def display_success_message
      puts
      puts "🎉 Successfully generated Rails SaaS application: #{app_name}"
      puts
      puts "Next steps:"
      puts "  cd #{app_name}"
      puts "  bin/setup"
      puts "  rails server"
      puts
      puts "Your application includes:"
      @config.installed_modules.each do |module_name|
        puts "  ✓ #{module_name.capitalize} module"
      end
      puts
      puts "For more information, visit: https://github.com/railsplan/railsplan"
    end

    def display_error_message(error)
      puts
      puts "❌ Failed to generate Rails application: #{error.message}"
      puts
      puts "Troubleshooting:"
      puts "  - Check that you have the required Ruby version installed"
      puts "  - Ensure you have write permissions in the current directory"
      puts "  - Try running with --verbose for more details"
      puts
      puts "For help, run: railsplan doctor"
    end
  end
end 