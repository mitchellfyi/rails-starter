# frozen_string_literal: true

require_relative 'base_command'
require 'railsplan/context_manager'
require 'railsplan/ai_generator'
require 'railsplan/ai_config'

module RailsPlan
  module Commands
    # Command for AI-powered refactoring of specific files or directories
    class RefactorCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
        @ai_config = AIConfig.new
      end
      
      def execute(path, options = {})
        puts "🔧 Refactoring with AI assistance..."
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
          
          # Generate refactored version using AI
          puts "\n🤖 Generating refactored code with AI..."
          ai_generator = AIGenerator.new(@ai_config, @context_manager)
          
          refactor_plan = ai_generator.generate("Refactor and modernize this code", {
            target_info: target_info,
            related_context: related_context,
            type: 'refactor',
            goals: options[:goals] || ['modernize', 'simplify', 'improve_performance'],
            creative: options[:creative],
            max_tokens: options[:max_tokens]
          })
          
          puts "✅ AI refactoring plan generated"
          
          # Display refactoring plan
          display_refactor_plan(refactor_plan)
          
          # Handle dry-run mode
          if options[:dry_run]
            puts "\n🔍 Dry-run mode: No changes will be applied"
            puts "💡 Remove --dry-run to apply changes"
            return true
          end
          
          # Prompt user for confirmation
          unless options[:force] || confirm_refactor(refactor_plan)
            puts "❌ Refactoring cancelled by user"
            return false
          end
          
          # Apply the refactoring
          puts "\n⚡ Applying refactoring..."
          success = apply_refactor(refactor_plan)
          
          if success
            puts "✅ Refactoring completed successfully!"
            puts "💡 Review the changes and run tests to ensure everything works"
            true
          else
            puts "❌ Refactoring failed during application"
            false
          end
          
        rescue StandardError => e
          puts "❌ Failed to refactor: #{e.message}"
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
          files: []
        }
        
        if File.file?(path)
          target_info[:content] = File.read(path)
          target_info[:files] = [path]
        elsif File.directory?(path)
          target_info[:files] = find_ruby_files(path)
          target_info[:content] = target_info[:files].map do |file|
            "# #{file}\n#{File.read(file)}\n\n"
          end.join
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
        elsif File.directory?(path)
          'directory'
        else
          'ruby_file'
        end
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
        end
        
        # Include related files (e.g., tests, specs)
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
        relevant_models.first(5)
      end
      
      def filter_relevant_controllers(controllers, target_info)
        return [] unless controllers
        
        # Include controllers related to the target
        relevant_controllers = controllers.select do |controller|
          target_info[:content]&.include?(controller['name']) ||
          target_info[:path].include?(controller['name'].underscore)
        end
        
        relevant_controllers.first(3)
      end
      
      def filter_relevant_routes(routes, target_info)
        return [] unless routes
        
        # Include routes that might be related
        relevant_routes = routes.select do |route|
          controller_name = route['controller']&.underscore
          target_info[:path].include?(controller_name) if controller_name
        end
        
        relevant_routes.first(10)
      end
      
      def find_related_files(target_info)
        related_files = []
        
        target_info[:files].each do |file|
          # Find corresponding test files
          test_file = file.gsub('app/', 'test/').gsub('.rb', '_test.rb')
          spec_file = file.gsub('app/', 'spec/').gsub('.rb', '_spec.rb')
          
          related_files << test_file if File.exist?(test_file)
          related_files << spec_file if File.exist?(spec_file)
        end
        
        related_files.map do |file|
          {
            path: file,
            content: File.read(file),
            type: 'test'
          }
        end.first(3) # Limit to avoid overwhelming
      end
      
      def display_refactor_plan(plan)
        puts "\n📋 Refactoring Plan:"
        puts "━" * 50
        
        if plan[:description]
          puts "📝 Description: #{plan[:description]}"
          puts ""
        end
        
        if plan[:improvements]&.any?
          puts "🔧 Improvements:"
          plan[:improvements].each do |improvement|
            puts "  ✨ #{improvement}"
          end
          puts ""
        end
        
        if plan[:changes]&.any?
          puts "📝 Changes to apply:"
          plan[:changes].each do |change|
            puts "  ✏️  #{change[:file]} - #{change[:description]}"
          end
          puts ""
        end
        
        if plan[:risks]&.any?
          puts "⚠️  Potential risks:"
          plan[:risks].each do |risk|
            puts "  ⚠️  #{risk}"
          end
          puts ""
        end
        
        puts "━" * 50
      end
      
      def confirm_refactor(plan)
        return true if force_mode?
        
        puts ""
        print "❓ Apply this refactoring? [y/N]: "
        response = STDIN.gets.strip.downcase
        
        %w[y yes].include?(response)
      end
      
      def apply_refactor(plan)
        success = true
        
        # Create backup
        backup_files = create_backup(plan[:changes])
        puts "💾 Created backup of original files"
        
        begin
          plan[:changes]&.each do |change|
            apply_file_change(change)
          end
          
          # Update context if we modified significant files
          if plan[:changes]&.any? { |c| c[:file].include?('app/models') || c[:file].include?('app/controllers') }
            puts "🔄 Updating application context..."
            @context_manager.extract_context
          end
          
        rescue StandardError => e
          puts "❌ Error during refactoring: #{e.message}"
          puts "💾 Original files backed up at #{backup_files}"
          success = false
        end
        
        success
      end
      
      def create_backup(changes)
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_dir = File.join(@context_manager.instance_variable_get(:@context_dir), 'backups', "refactor_#{timestamp}")
        FileUtils.mkdir_p(backup_dir)
        
        changes&.each do |change|
          file_path = change[:file]
          next unless File.exist?(file_path)
          
          backup_file_path = File.join(backup_dir, file_path)
          FileUtils.mkdir_p(File.dirname(backup_file_path))
          FileUtils.cp(file_path, backup_file_path)
        end
        
        backup_dir
      end
      
      def apply_file_change(change)
        file_path = change[:file]
        new_content = change[:content]
        
        if new_content
          File.write(file_path, new_content)
          puts "  ✏️  Refactored #{file_path}"
        end
      end
    end
  end
end