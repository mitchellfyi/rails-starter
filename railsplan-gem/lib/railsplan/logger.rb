# frozen_string_literal: true

require "logger"
require "fileutils"

module RailsPlan
  # Structured logger for RailsPlan operations
  class Logger
    attr_reader :logger, :log_file

    def initialize
      @log_file = determine_log_file
      setup_logger
    end

    # Log an info message
    def info(message)
      logger.info(format_message("INFO", message))
    end

    # Log a warning message
    def warn(message)
      logger.warn(format_message("WARN", message))
    end

    # Log an error message
    def error(message)
      logger.error(format_message("ERROR", message))
    end

    # Log a debug message
    def debug(message)
      logger.debug(format_message("DEBUG", message))
    end

    # Log a fatal message
    def fatal(message)
      logger.fatal(format_message("FATAL", message))
    end

    # Log with custom level
    def log(level, message)
      logger.send(level.downcase, format_message(level.upcase, message))
    end

    # Clear log file
    def clear
      FileUtils.rm_f(log_file) if File.exist?(log_file)
    end

    # Get log contents
    def contents
      return "" unless File.exist?(log_file)
      File.read(log_file)
    end

    # Get recent log entries
    def recent(lines = 50)
      return "" unless File.exist?(log_file)
      
      output = `tail -n #{lines} "#{log_file}" 2>/dev/null`
      output || ""
    end

    private

    def determine_log_file
      # Try to find a Rails application directory
      current_dir = Dir.pwd
      
      # Look for Rails app in current directory or parent directories
      while current_dir != "/"
        if File.exist?(File.join(current_dir, "config", "application.rb"))
          return File.join(current_dir, "log", "railsplan.log")
        end
        current_dir = File.dirname(current_dir)
      end
      
      # Fallback to current directory
      File.join(Dir.pwd, "railsplan.log")
    end

    def setup_logger
      # Ensure log directory exists
      log_dir = File.dirname(log_file)
      FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
      
      # Create logger
      @logger = ::Logger.new(log_file, "daily")
      
      # Set log level based on environment
      log_level = ENV["RAILSPLAN_LOG_LEVEL"] || "INFO"
      @logger.level = ::Logger.const_get(log_level.upcase)
      
      # Set format
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
      end
    end

    def format_message(level, message)
      # Add timestamp and context
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      context = get_context
      
      if context.empty?
        "[#{timestamp}] [#{level}] #{message}"
      else
        "[#{timestamp}] [#{level}] [#{context}] #{message}"
      end
    end

    def get_context
      # Try to determine context from current directory
      current_dir = Dir.pwd
      
      # If we're in a Rails app, use the app name
      if File.exist?(File.join(current_dir, "config", "application.rb"))
        File.basename(current_dir)
      else
        # Use current directory name
        File.basename(current_dir)
      end
    rescue
      "unknown"
    end
  end
end 