# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/context_manager"

module RailsPlan
  module Commands
    # Command for indexing Rails application context
    class IndexCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
      end
      
      def execute(options = {})
        puts "🔍 Indexing Rails application context..."
        
        unless rails_app?
          puts "❌ Not in a Rails application directory"
          return false
        end
        
        begin
          context = @context_manager.extract_context
          
          puts "✅ Context extracted successfully!"
          puts ""
          
          display_context_summary(context)
          
          puts ""
          puts "📁 Context saved to #{@context_manager.context_path}"
          puts "💡 Use 'railsplan generate \"description\"' to generate code with this context"
          
          true
        rescue StandardError => e
          puts "❌ Failed to extract context: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def rails_app?
        File.exist?("config/application.rb") || File.exist?("Gemfile")
      end
      
      def display_context_summary(context)
        puts "📋 Context Summary:"
        puts "  App: #{context["app_name"]}" if context["app_name"]
        
        if context["models"] && !context["models"].empty?
          puts "  Models: #{context["models"].length}"
          context["models"].take(5).each do |model|
            puts "    - #{model["class_name"]}"
          end
          puts "    ... and #{context["models"].length - 5} more" if context["models"].length > 5
        else
          puts "  Models: 0"
        end
        
        if context["schema"] && !context["schema"].empty?
          puts "  Database tables: #{context["schema"].keys.length}"
          puts "    #{context["schema"].keys.take(5).join(", ")}"
          puts "    ... and #{context["schema"].keys.length - 5} more" if context["schema"].keys.length > 5
        else
          puts "  Database tables: 0"
        end
        
        if context["routes"] && !context["routes"].empty?
          puts "  Routes: #{context["routes"].length}"
        else
          puts "  Routes: 0"
        end
        
        if context["controllers"] && !context["controllers"].empty?
          puts "  Controllers: #{context["controllers"].length}"
        else
          puts "  Controllers: 0"
        end
        
        if context["modules"] && !context["modules"].empty?
          puts "  Installed modules: #{context["modules"].join(", ")}"
        else
          puts "  Installed modules: none"
        end
      end
    end
  end
end