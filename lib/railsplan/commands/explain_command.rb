# frozen_string_literal: true

require_relative 'base_command'
require 'railsplan/context_manager'
require 'railsplan/ai_generator'
require 'railsplan/ai_config'

module RailsPlan
  module Commands
    # Command for explaining code in plain English using AI
    class ExplainCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
        @ai_config = AIConfig.new
      end
      
      def execute(path, options = {})
        puts "🔍 Explaining code with AI assistance..."
        puts "📁 Target: #{path}"
        
        unless File.exist?(path)
          puts "❌ Path not found: #{path}"
          return false
        end
        
        unless @ai_config.configured?
          puts "❌ AI provider not configured"
          puts "💡 Set up AI configuration in ~/.railsplan/ai.yml"
          return false
        end
        
        begin
          # Load the target file(s) and related context
          target_info = analyze_target(path)
          
          # Get related context from the application
          related_context = get_related_context(target_info)
          
          puts "✅ Analyzed target and loaded related context"
          
          # Generate explanation using AI
          puts "\n🤖 Generating explanation with AI..."
          ai_generator = AIGenerator.new(@ai_config, @context_manager)
          
          explanation = ai_generator.generate("Explain this code in plain English", {
            target_info: target_info,
            related_context: related_context,
            type: 'explanation',
            audience: options[:audience] || 'developer',
            detail_level: options[:detail] || 'medium',
            max_tokens: options[:max_tokens]
          })
          
          puts "✅ AI explanation generated"
          
          # Display the explanation
          display_explanation(explanation, target_info)
          
          # Save explanation to file if requested
          if options[:save]
            save_explanation(explanation, target_info, options[:save])
          end
          
          true
          
        rescue StandardError => e
          puts "❌ Failed to explain code: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def analyze_target(path)
        target_info = {
          path: path,
          type: determine_file_type(path),
          content: nil,
          files: [],
          metadata: {}
        }
        
        if File.file?(path)
          target_info[:content] = File.read(path)
          target_info[:files] = [path]
          target_info[:metadata] = extract_file_metadata(path)
        elsif File.directory?(path)
          target_info[:files] = find_ruby_files(path)
          target_info[:content] = target_info[:files].map do |file|
            "# #{file}\n#{File.read(file)}\n\n"
          end.join
          target_info[:metadata] = { file_count: target_info[:files].length }
        end
        
        target_info
      end
      
      def determine_file_type(path)
        if path.include?('/models/')
          'model'
        elsif path.include?('/controllers/')
          'controller'
        elsif path.include?('/views/')
          'view'
        elsif path.include?('/services/')
          'service'
        elsif path.include?('/jobs/')
          'job'
        elsif path.include?('/mailers/')
          'mailer'
        elsif path.include?('/helpers/')
          'helper'
        elsif path.include?('/lib/')
          'library'
        elsif path.include?('/test/') || path.include?('/spec/')
          'test'
        elsif File.directory?(path)
          'directory'
        else
          'ruby_file'
        end
      end
      
      def extract_file_metadata(file_path)
        metadata = {}
        
        return metadata unless File.exist?(file_path)
        
        content = File.read(file_path)
        
        # Count lines
        metadata[:lines] = content.lines.count
        
        # Extract class/module names
        metadata[:classes] = content.scan(/class\s+(\w+)/).flatten
        metadata[:modules] = content.scan(/module\s+(\w+)/).flatten
        
        # Extract method names
        metadata[:methods] = content.scan(/def\s+(\w+)/).flatten
        
        # Check for Rails-specific patterns
        metadata[:rails_model] = content.include?('ActiveRecord::Base') || content.include?('ApplicationRecord')
        metadata[:rails_controller] = content.include?('ActionController::Base') || content.include?('ApplicationController')
        metadata[:rails_job] = content.include?('ActiveJob::Base') || content.include?('ApplicationJob')
        metadata[:rails_mailer] = content.include?('ActionMailer::Base') || content.include?('ApplicationMailer')
        
        # Check for common patterns
        metadata[:has_validations] = content.include?('validates') || content.include?('validate')
        metadata[:has_associations] = content.include?('belongs_to') || content.include?('has_many') || content.include?('has_one')
        metadata[:has_callbacks] = content.include?('before_') || content.include?('after_') || content.include?('around_')
        
        metadata
      end
      
      def find_ruby_files(directory)
        Dir.glob(File.join(directory, '**', '*.rb')).select { |f| File.file?(f) }
      end
      
      def get_related_context(target_info)
        context = {}
        
        # Load application context if available
        if File.exist?(@context_manager.context_path)
          app_context = JSON.parse(File.read(@context_manager.context_path))
          
          # Include relevant models, controllers, routes based on target
          context[:models] = filter_relevant_models(app_context['models'], target_info)
          context[:controllers] = filter_relevant_controllers(app_context['controllers'], target_info)
          context[:routes] = filter_relevant_routes(app_context['routes'], target_info)
          context[:schema] = filter_relevant_schema(app_context['schema'], target_info)
        end
        
        # Include related files for context
        context[:related_files] = find_related_files(target_info)
        
        context
      end
      
      def filter_relevant_models(models, target_info)
        return [] unless models
        
        # Include models mentioned in the target files
        relevant_models = models.select do |model|
          target_info[:content]&.include?(model['name']) ||
          target_info[:path].include?(model['name'].underscore)
        end
        
        # Limit to avoid overwhelming the AI
        relevant_models.first(3)
      end
      
      def filter_relevant_controllers(controllers, target_info)
        return [] unless controllers
        
        # Include controllers related to the target
        relevant_controllers = controllers.select do |controller|
          target_info[:content]&.include?(controller['name']) ||
          target_info[:path].include?(controller['name'].underscore)
        end
        
        relevant_controllers.first(2)
      end
      
      def filter_relevant_routes(routes, target_info)
        return [] unless routes
        
        # Include routes that might be related
        relevant_routes = routes.select do |route|
          controller_name = route['controller']&.underscore
          target_info[:path].include?(controller_name) if controller_name
        end
        
        relevant_routes.first(5)
      end
      
      def filter_relevant_schema(schema, target_info)
        return {} unless schema
        
        # If explaining a model, include its table schema
        if target_info[:type] == 'model'
          model_name = File.basename(target_info[:path], '.rb')
          table_name = model_name.pluralize
          
          return { table_name => schema[table_name] } if schema[table_name]
        end
        
        {}
      end
      
      def find_related_files(target_info)
        related_files = []
        
        # For models, include migration files
        if target_info[:type] == 'model'
          model_name = File.basename(target_info[:path], '.rb')
          migration_pattern = File.join('db', 'migrate', "*#{model_name.pluralize}*.rb")
          related_files.concat(Dir.glob(migration_pattern))
        end
        
        # For controllers, include view files
        if target_info[:type] == 'controller'
          controller_name = File.basename(target_info[:path], '_controller.rb')
          view_pattern = File.join('app', 'views', controller_name, '*.html.*')
          related_files.concat(Dir.glob(view_pattern).first(3))
        end
        
        related_files.map do |file|
          {
            path: file,
            content: File.read(file).lines.first(20).join, # First 20 lines only
            type: determine_file_type(file)
          }
        end.first(2) # Limit to avoid overwhelming
      end
      
      def display_explanation(explanation, target_info)
        puts "\n📖 Code Explanation:"
        puts "━" * 60
        
        # Display file information
        puts "📁 File: #{target_info[:path]}"
        puts "📋 Type: #{target_info[:type].humanize}"
        
        if target_info[:metadata][:lines]
          puts "📏 Lines: #{target_info[:metadata][:lines]}"
        end
        
        if target_info[:metadata][:classes]&.any?
          puts "🏗️  Classes: #{target_info[:metadata][:classes].join(', ')}"
        end
        
        if target_info[:metadata][:methods]&.any?
          method_count = target_info[:metadata][:methods].count
          sample_methods = target_info[:metadata][:methods].first(3).join(', ')
          puts "⚙️  Methods: #{sample_methods}#{method_count > 3 ? " (#{method_count - 3} more...)" : ""}"
        end
        
        puts ""
        puts "━" * 60
        
        # Display the AI explanation
        if explanation[:summary]
          puts "📝 Summary:"
          puts explanation[:summary]
          puts ""
        end
        
        if explanation[:purpose]
          puts "🎯 Purpose:"
          puts explanation[:purpose]
          puts ""
        end
        
        if explanation[:key_components]&.any?
          puts "🔧 Key Components:"
          explanation[:key_components].each do |component|
            puts "  • #{component}"
          end
          puts ""
        end
        
        if explanation[:how_it_works]
          puts "⚙️  How it works:"
          puts explanation[:how_it_works]
          puts ""
        end
        
        if explanation[:relationships]&.any?
          puts "🔗 Relationships:"
          explanation[:relationships].each do |relationship|
            puts "  • #{relationship}"
          end
          puts ""
        end
        
        if explanation[:important_notes]&.any?
          puts "💡 Important Notes:"
          explanation[:important_notes].each do |note|
            puts "  • #{note}"
          end
          puts ""
        end
        
        if explanation[:potential_improvements]&.any?
          puts "✨ Potential Improvements:"
          explanation[:potential_improvements].each do |improvement|
            puts "  • #{improvement}"
          end
          puts ""
        end
        
        puts "━" * 60
      end
      
      def save_explanation(explanation, target_info, save_path)
        content = generate_explanation_markdown(explanation, target_info)
        
        File.write(save_path, content)
        puts "💾 Explanation saved to #{save_path}"
      end
      
      def generate_explanation_markdown(explanation, target_info)
        content = []
        content << "# Code Explanation: #{target_info[:path]}"
        content << ""
        content << "**Generated by RailsPlan at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}**"
        content << ""
        content << "## File Information"
        content << "- **Path**: `#{target_info[:path]}`"
        content << "- **Type**: #{target_info[:type].humanize}"
        
        if target_info[:metadata][:lines]
          content << "- **Lines**: #{target_info[:metadata][:lines]}"
        end
        
        content << ""
        
        if explanation[:summary]
          content << "## Summary"
          content << explanation[:summary]
          content << ""
        end
        
        if explanation[:purpose]
          content << "## Purpose"
          content << explanation[:purpose]
          content << ""
        end
        
        if explanation[:key_components]&.any?
          content << "## Key Components"
          explanation[:key_components].each do |component|
            content << "- #{component}"
          end
          content << ""
        end
        
        if explanation[:how_it_works]
          content << "## How It Works"
          content << explanation[:how_it_works]
          content << ""
        end
        
        if explanation[:relationships]&.any?
          content << "## Relationships"
          explanation[:relationships].each do |relationship|
            content << "- #{relationship}"
          end
          content << ""
        end
        
        if explanation[:important_notes]&.any?
          content << "## Important Notes"
          explanation[:important_notes].each do |note|
            content << "- #{note}"
          end
          content << ""
        end
        
        if explanation[:potential_improvements]&.any?
          content << "## Potential Improvements"
          explanation[:potential_improvements].each do |improvement|
            content << "- #{improvement}"
          end
          content << ""
        end
        
        content.join("\n")
      end
    end
  end
end