# frozen_string_literal: true

require_relative 'base_command'
require 'railsplan/context_manager'
require 'railsplan/ai_generator'
require 'railsplan/ai_config'

module RailsPlan
  module Commands
    # Command for AI-powered fixes based on issue descriptions
    class FixCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
        @ai_config = AIConfig.new
      end
      
      def execute(issue_description, options = {})
        puts "🔧 Applying AI-powered fix..."
        puts "📋 Issue: #{issue_description}"
        
        unless @ai_config.configured?
          puts "❌ AI provider not configured"
          puts "💡 Set up AI configuration in ~/.railsplan/ai.yml"
          return false
        end
        
        begin
          # Load application context if available
          context = load_application_context_if_exists
          
          # Generate fix using AI
          puts "\n🤖 Generating fix with AI..."
          ai_generator = AIGenerator.new(@ai_config, @context_manager)
          
          fix_plan = ai_generator.generate("Fix this issue: #{issue_description}", {
            context: context,
            type: 'fix',
            issue_description: issue_description,
            creative: options[:creative],
            max_tokens: options[:max_tokens]
          })
          
          puts "✅ AI fix plan generated"
          
          # Display fix plan
          display_fix_plan(fix_plan)
          
          # Handle dry-run mode
          if options[:dry_run]
            puts "\n🔍 Dry-run mode: No changes will be applied"
            puts "💡 Remove --dry-run to apply changes"
            return true
          end
          
          # Prompt user for confirmation
          unless options[:force] || confirm_fix(fix_plan)
            puts "❌ Fix cancelled by user"
            return false
          end
          
          # Apply the fix
          puts "\n⚡ Applying fix..."
          success = apply_fix(fix_plan)
          
          if success
            puts "✅ Fix applied successfully!"
            puts "💡 Review the changes and run tests to ensure everything works"
            true
          else
            puts "❌ Fix failed during application"
            false
          end
          
        rescue StandardError => e
          puts "❌ Failed to apply fix: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def load_application_context_if_exists
        if File.exist?(@context_manager.context_path)
          JSON.parse(File.read(@context_manager.context_path))
        else
          {}
        end
      end
      
      def display_fix_plan(plan)
        puts "\n📋 Fix Plan:"
        puts "━" * 50
        
        if plan[:description]
          puts "📝 Description: #{plan[:description]}"
          puts ""
        end
        
        if plan[:root_cause]
          puts "🔍 Root Cause: #{plan[:root_cause]}"
          puts ""
        end
        
        if plan[:solution_approach]
          puts "🎯 Solution Approach: #{plan[:solution_approach]}"
          puts ""
        end
        
        if plan[:files_to_modify]&.any?
          puts "📝 Files to modify:"
          plan[:files_to_modify].each do |file|
            puts "  ✏️  #{file[:path]} - #{file[:description] || 'Modifications'}"
          end
          puts ""
        end
        
        if plan[:files_to_create]&.any?
          puts "📝 Files to create:"
          plan[:files_to_create].each do |file|
            puts "  ➕ #{file[:path]} - #{file[:description] || 'New file'}"
          end
          puts ""
        end
        
        if plan[:commands]&.any?
          puts "📝 Commands to run:"
          plan[:commands].each do |command|
            puts "  ⚡ #{command}"
          end
          puts ""
        end
        
        if plan[:testing_instructions]
          puts "🧪 Testing Instructions:"
          puts plan[:testing_instructions]
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
      
      def confirm_fix(plan)
        return true if force_mode?
        
        puts ""
        print "❓ Apply this fix? [y/N]: "
        response = STDIN.gets.strip.downcase
        
        %w[y yes].include?(response)
      end
      
      def apply_fix(plan)
        success = true
        
        # Create backup of current state
        backup_dir = create_backup(plan)
        puts "💾 Created backup at #{backup_dir}" if backup_dir
        
        begin
          # Apply file modifications
          if plan[:files_to_modify]&.any?
            puts "✏️  Modifying files..."
            plan[:files_to_modify].each do |file_change|
              apply_file_modification(file_change)
            end
          end
          
          # Create new files
          if plan[:files_to_create]&.any?
            puts "➕ Creating new files..."
            plan[:files_to_create].each do |file_creation|
              create_new_file(file_creation)
            end
          end
          
          # Run commands
          if plan[:commands]&.any?
            puts "⚡ Running commands..."
            plan[:commands].each do |command|
              run_command(command)
            end
          end
          
          # Update context if significant changes were made
          if (plan[:files_to_modify]&.any? { |f| f[:path].include?('app/models') || f[:path].include?('app/controllers') }) ||
             (plan[:files_to_create]&.any? { |f| f[:path].include?('app/models') || f[:path].include?('app/controllers') })
            puts "🔄 Updating application context..."
            @context_manager.extract_context
          end
          
        rescue StandardError => e
          puts "❌ Error during fix application: #{e.message}"
          puts "💾 Backup available at #{backup_dir}" if backup_dir
          success = false
        end
        
        success
      end
      
      def create_backup(plan)
        return nil unless plan[:files_to_modify]&.any?
        
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_dir = File.join(@context_manager.instance_variable_get(:@context_dir), 'backups', "fix_#{timestamp}")
        FileUtils.mkdir_p(backup_dir)
        
        plan[:files_to_modify].each do |file_change|
          file_path = file_change[:path]
          next unless File.exist?(file_path)
          
          backup_file_path = File.join(backup_dir, file_path)
          FileUtils.mkdir_p(File.dirname(backup_file_path))
          FileUtils.cp(file_path, backup_file_path)
        end
        
        backup_dir
      end
      
      def apply_file_modification(file_change)
        file_path = file_change[:path]
        
        if file_change[:content]
          # Direct content replacement
          File.write(file_path, file_change[:content])
          puts "  ✏️  Modified #{file_path}"
        elsif file_change[:patches]
          # Apply patches/diffs
          file_change[:patches].each do |patch|
            apply_patch(file_path, patch)
          end
          puts "  ✏️  Applied patches to #{file_path}"
        end
      end
      
      def apply_patch(file_path, patch)
        return unless File.exist?(file_path)
        
        content = File.read(file_path)
        
        if patch[:type] == 'replace' && patch[:old_content] && patch[:new_content]
          content.gsub!(patch[:old_content], patch[:new_content])
        elsif patch[:type] == 'insert' && patch[:after_line] && patch[:content]
          lines = content.lines
          insert_index = patch[:after_line]
          lines.insert(insert_index, patch[:content] + "\n")
          content = lines.join
        elsif patch[:type] == 'append' && patch[:content]
          content += "\n" + patch[:content]
        end
        
        File.write(file_path, content)
      end
      
      def create_new_file(file_creation)
        file_path = file_creation[:path]
        content = file_creation[:content] || ""
        
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, content)
        puts "  ➕ Created #{file_path}"
      end
      
      def run_command(command)
        puts "  ⚡ Running: #{command}"
        
        unless system(command)
          puts "  ❌ Command failed: #{command}"
          raise "Command execution failed: #{command}"
        end
      end
    end
  end
end