# frozen_string_literal: true

require_relative 'base_command'
require_relative 'index_command'
require 'railsplan/context_manager'
require 'yaml'

module RailsPlan
  module Commands
    # Command for initializing .railsplan/ directory for existing Rails projects
    class InitCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
      end
      
      def execute(options = {})
        puts "🚀 Initializing RailsPlan for existing Rails application..."
        
        unless rails_app?
          puts "❌ Not in a Rails application directory"
          puts "💡 Make sure you're in the root of a Rails project (with Gemfile and config/application.rb)"
          return false
        end
        
        begin
          # Setup .railsplan directory structure
          @context_manager.setup_directory
          puts "✅ Created .railsplan/ directory structure"
          
          # Detect and save application settings
          settings = detect_app_settings
          save_settings(settings)
          puts "✅ Detected and saved application settings"
          
          # Run index command to extract context
          puts "\n🔍 Extracting application context..."
          index_command = IndexCommand.new(verbose: verbose)
          unless index_command.execute(options)
            puts "⚠️  Context extraction failed, but .railsplan/ directory is ready"
          else
            puts "✅ Application context extracted successfully"
          end
          
          # Create initial prompts log
          create_prompts_log
          puts "✅ Created prompts log file"
          
          puts "\n🎉 RailsPlan initialization complete!"
          puts ""
          puts "📁 Created files:"
          puts "  .railsplan/context.json    - Application schema and models"
          puts "  .railsplan/settings.yml    - Detected application settings"
          puts "  .railsplan/prompts.log     - AI interaction history"
          puts "  .railsplan/.gitignore      - Git ignore rules"
          puts ""
          puts "💡 Next steps:"
          puts "  railsplan upgrade \"<instruction>\"  - AI-powered upgrades"
          puts "  railsplan doctor                    - Scan for issues"
          puts "  railsplan refactor <path>           - Refactor specific files"
          
          true
        rescue StandardError => e
          puts "❌ Failed to initialize RailsPlan: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def rails_app?
        File.exist?("config/application.rb") && File.exist?("Gemfile")
      end
      
      def detect_app_settings
        settings = {
          'generated_at' => Time.now.iso8601,
          'app_name' => detect_app_name,
          'ruby_version' => detect_ruby_version,
          'rails_version' => detect_rails_version,
          'database_adapter' => detect_database_adapter,
          'key_gems' => detect_key_gems,
          'features' => detect_features
        }
        
        log_verbose("Detected settings: #{settings.inspect}")
        settings
      end
      
      def detect_app_name
        if File.exist?("config/application.rb")
          content = File.read("config/application.rb")
          match = content.match(/module\s+(\w+)/m)
          return match[1] if match
        end
        
        # Fallback to directory name
        File.basename(Dir.pwd).gsub(/[^a-zA-Z0-9_]/, '_').camelize
      end
      
      def detect_ruby_version
        if File.exist?(".ruby-version")
          File.read(".ruby-version").strip
        elsif File.exist?("Gemfile")
          content = File.read("Gemfile")
          match = content.match(/ruby\s+['"]([^'"]+)['"]/m)
          return match[1] if match
        end
        
        RUBY_VERSION
      end
      
      def detect_rails_version
        return nil unless File.exist?("Gemfile.lock")
        
        content = File.read("Gemfile.lock")
        match = content.match(/rails\s+\(([^)]+)\)/m)
        match ? match[1] : nil
      end
      
      def detect_database_adapter
        return nil unless File.exist?("config/database.yml")
        
        begin
          db_config = YAML.load_file("config/database.yml")
          development_config = db_config['development'] || db_config[:development]
          return development_config['adapter'] if development_config
        rescue StandardError => e
          log_verbose("Failed to parse database.yml: #{e.message}")
        end
        
        # Fallback to checking Gemfile
        return 'postgresql' if gemfile_includes?('pg')
        return 'mysql2' if gemfile_includes?('mysql2')
        return 'sqlite3' if gemfile_includes?('sqlite3')
        
        nil
      end
      
      def detect_key_gems
        return [] unless File.exist?("Gemfile")
        
        content = File.read("Gemfile")
        key_gems = []
        
        # Check for common Rails gems
        key_gems << 'devise' if content.include?('devise')
        key_gems << 'sidekiq' if content.include?('sidekiq')
        key_gems << 'redis' if content.include?('redis')
        key_gems << 'elasticsearch' if content.include?('elasticsearch')
        key_gems << 'stripe' if content.include?('stripe')
        key_gems << 'aws-sdk' if content.include?('aws-sdk')
        key_gems << 'carrierwave' if content.include?('carrierwave')
        key_gems << 'image_processing' if content.include?('image_processing')
        key_gems << 'tailwindcss' if content.include?('tailwindcss')
        key_gems << 'stimulus' if content.include?('stimulus')
        key_gems << 'turbo' if content.include?('turbo')
        key_gems << 'hotwire' if content.include?('hotwire')
        
        key_gems
      end
      
      def detect_features
        features = []
        
        # Check for authentication
        features << 'authentication' if File.exist?("app/models/user.rb") || gemfile_includes?('devise')
        
        # Check for admin panel
        features << 'admin' if Dir.exist?("app/controllers/admin") || gemfile_includes?('rails_admin')
        
        # Check for API
        features << 'api' if Dir.exist?("app/controllers/api") || Dir.exist?("app/controllers/application_controller.rb")
        
        # Check for background jobs
        features << 'background_jobs' if Dir.exist?("app/jobs") || gemfile_includes?('sidekiq')
        
        # Check for file uploads
        features << 'file_uploads' if Dir.exist?("app/uploaders") || gemfile_includes?('carrierwave')
        
        # Check for real-time features
        features << 'realtime' if Dir.exist?("app/channels") || gemfile_includes?('actioncable')
        
        # Check for testing framework
        features << 'rspec' if File.exist?("spec/spec_helper.rb")
        features << 'minitest' if File.exist?("test/test_helper.rb")
        
        features
      end
      
      def gemfile_includes?(gem_name)
        return false unless File.exist?("Gemfile")
        
        content = File.read("Gemfile")
        content.include?(gem_name)
      end
      
      def save_settings(settings)
        settings_path = File.join(@context_manager.instance_variable_get(:@context_dir), 'settings.yml')
        File.write(settings_path, settings.to_yaml)
      end
      
      def create_prompts_log
        prompts_log_path = @context_manager.prompts_log_path
        unless File.exist?(prompts_log_path)
          File.write(prompts_log_path, "# RailsPlan AI Prompts Log\n# Generated at #{Time.now.iso8601}\n\n")
        end
      end
    end
  end
end