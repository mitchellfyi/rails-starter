# frozen_string_literal: true

require "open3"
require "fileutils"

module RailsPlan
  # Handles the actual Rails application generation
  class AppGenerator
    attr_reader :app_name, :options, :logger

    def initialize(app_name, options = {})
      @app_name = app_name
      @options = options
      @logger = RailsPlan.logger
    end

    # Generate the Rails application
    def generate
      @logger.info("Generating Rails application: #{app_name}")
      
      # Build Rails new command
      command = build_rails_command
      
      @logger.info("Executing: #{command}")
      
      # Execute the command
      execute_rails_command(command)
    end

    private

    def build_rails_command
      # Start with basic rails new command
      command = ["rails", "new", app_name]
      
      # Add database option (default to PostgreSQL)
      command << "--database=postgresql"
      
      # Add CSS option (default to Tailwind)
      command << "--css=tailwind"
      
      # Skip JavaScript (we'll add it manually if needed)
      command << "--skip-javascript"
      
      # Add development mode
      command << "--dev"
      
      # Add other options based on preferences
      command << "--skip-test" if options[:skip_test]
      command << "--skip-system-test" if options[:skip_system_test]
      command << "--skip-bundle" if options[:skip_bundle]
      command << "--skip-git" if options[:skip_git]
      command << "--skip-action-mailer" if options[:skip_action_mailer]
      command << "--skip-action-mailbox" if options[:skip_action_mailbox]
      command << "--skip-action-text" if options[:skip_action_text]
      command << "--skip-active-storage" if options[:skip_active_storage]
      command << "--skip-action-cable" if options[:skip_action_cable]
      
      command.join(" ")
    end

    def execute_rails_command(command)
      # Use Open3 to capture output and provide real-time feedback
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
        # Set up output handling
        stdout_thread = Thread.new do
          stdout.each_line do |line|
            handle_output(line.chomp, :stdout)
          end
        end
        
        stderr_thread = Thread.new do
          stderr.each_line do |line|
            handle_output(line.chomp, :stderr)
          end
        end
        
        # Wait for the process to complete
        exit_status = wait_thr.value
        
        # Wait for output threads to finish
        stdout_thread.join
        stderr_thread.join
        
        # Check if the command was successful
        unless exit_status.success?
          raise Error, "Rails application generation failed with exit code #{exit_status.exitstatus}"
        end
        
        @logger.info("Rails application generation completed successfully")
      end
    end

    def handle_output(line, stream)
      return if line.empty?
      
      # Log the output
      if stream == :stderr
        @logger.warn(line)
      else
        @logger.info(line)
      end
      
      # Also output to console for user feedback
      unless options[:quiet]
        if stream == :stderr
          puts "⚠️  #{line}"
        else
          puts line
        end
      end
    end

    # Alternative method using system for simpler cases
    def execute_rails_command_simple(command)
      @logger.info("Executing Rails command: #{command}")
      
      unless system(command)
        raise Error, "Rails application generation failed"
      end
      
      @logger.info("Rails application generation completed successfully")
    end
  end
end 