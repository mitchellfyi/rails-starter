# frozen_string_literal: true

require_relative 'base_command'
require 'railsplan/context_manager'
require 'railsplan/ai_generator'
require 'railsplan/ai_config'
require 'yaml'

module RailsPlan
  module Commands
    # Command for AI-powered upgrades to existing Rails applications
    class UpgradeCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
        @ai_config = AIConfig.new
      end
      
      def execute(instruction, options = {})
        puts "🔧 Running AI-powered upgrade..."
        puts "📋 Instruction: #{instruction}"
        
        unless railsplan_initialized?
          puts "❌ RailsPlan not initialized for this project"
          puts "💡 Run 'railsplan init' first to set up .railsplan/ directory"
          return false
        end
        
        unless @ai_config.configured?
          puts "❌ AI provider not configured"
          puts "💡 Set up AI configuration in ~/.railsplan/ai.yml"
          return false
        end
        
        begin
          # Load application context and settings
          context = load_application_context
          settings = load_settings
          
          puts "✅ Loaded application context (#{context['models']&.length || 0} models, #{context['controllers']&.length || 0} controllers)"
          
          # Generate upgrade plan using AI
          puts "\n🤖 Generating upgrade plan with AI..."
          ai_generator = AIGenerator.new(@ai_config, @context_manager)
          
          upgrade_plan = ai_generator.generate(instruction, {
            context: context,
            settings: settings,
            type: 'upgrade',
            creative: options[:creative],
            max_tokens: options[:max_tokens]
          })
          
          puts "✅ AI upgrade plan generated"
          
          # Display upgrade plan to user
          display_upgrade_plan(upgrade_plan)
          
          # Handle dry-run mode
          if options[:dry_run]
            puts "\n🔍 Dry-run mode: No changes will be applied"
            puts "💡 Remove --dry-run to apply changes"
            return true
          end
          
          # Prompt user for confirmation
          unless options[:force] || confirm_upgrade(upgrade_plan)
            puts "❌ Upgrade cancelled by user"
            return false
          end
          
          # Apply the upgrade
          puts "\n⚡ Applying upgrade..."
          success = apply_upgrade(upgrade_plan)
          
          if success
            puts "✅ Upgrade completed successfully!"
            puts "💡 Don't forget to run tests and review the changes"
            true
          else
            puts "❌ Upgrade failed during application"
            false
          end
          
        rescue StandardError => e
          puts "❌ Failed to run upgrade: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def railsplan_initialized?
        File.exist?(@context_manager.context_path) && 
        File.exist?(@context_manager.settings_path)
      end
      
      def load_application_context
        unless File.exist?(@context_manager.context_path)
          raise "Context file not found. Run 'railsplan index' to generate context."
        end
        
        JSON.parse(File.read(@context_manager.context_path))
      end
      
      def load_settings
        unless File.exist?(@context_manager.settings_path)
          raise "Settings file not found. Run 'railsplan init' to generate settings."
        end
        
        YAML.load_file(@context_manager.settings_path)
      end
      
      def display_upgrade_plan(plan)
        puts "\n📋 Upgrade Plan:"
        puts "━" * 50
        
        if plan[:description]
          puts "📝 Description: #{plan[:description]}"
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
        
        if plan[:migrations]&.any?
          puts "📝 Migrations to create:"
          plan[:migrations].each do |migration|
            puts "  🗃️  #{migration[:name]} - #{migration[:description] || 'Database migration'}"
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
        
        if plan[:warnings]&.any?
          puts "⚠️  Warnings:"
          plan[:warnings].each do |warning|
            puts "  ⚠️  #{warning}"
          end
          puts ""
        end
        
        puts "━" * 50
      end
      
      def confirm_upgrade(plan)
        return true if force_mode?
        
        puts ""
        print "❓ Apply this upgrade? [y/N]: "
        response = STDIN.gets.strip.downcase
        
        %w[y yes].include?(response)
      end
      
      def apply_upgrade(plan)
        success = true
        
        # Create backup of current state
        backup_dir = create_backup
        puts "💾 Created backup at #{backup_dir}"
        
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
          
          # Create migrations
          if plan[:migrations]&.any?
            puts "🗃️  Creating migrations..."
            plan[:migrations].each do |migration|
              create_migration(migration)
            end
          end
          
          # Run commands
          if plan[:commands]&.any?
            puts "⚡ Running commands..."
            plan[:commands].each do |command|
              run_command(command)
            end
          end
          
          # Update context after changes
          puts "🔄 Updating application context..."
          @context_manager.extract_context
          
        rescue StandardError => e
          puts "❌ Error during upgrade application: #{e.message}"
          puts "💾 Backup available at #{backup_dir}"
          success = false
        end
        
        success
      end
      
      def create_backup
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        backup_dir = File.join(@context_manager.instance_variable_get(:@context_dir), 'backups', timestamp)
        FileUtils.mkdir_p(backup_dir)
        
        # Copy current app state to backup
        %w[app config db].each do |dir|
          next unless Dir.exist?(dir)
          FileUtils.cp_r(dir, backup_dir)
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
      
      def create_migration(migration)
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        file_name = "#{timestamp}_#{migration[:name].underscore}.rb"
        migration_path = File.join('db', 'migrate', file_name)
        
        content = migration[:content] || generate_migration_template(migration[:name])
        
        FileUtils.mkdir_p(File.dirname(migration_path))
        File.write(migration_path, content)
        puts "  🗃️  Created migration #{migration_path}"
      end
      
      def generate_migration_template(name)
        class_name = name.camelize
        
        <<~RUBY
          class #{class_name} < ActiveRecord::Migration[7.0]
            def change
              # Add your migration logic here
            end
          end
        RUBY
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