# frozen_string_literal: true

module Railsplan
  module Web
    class UpgradeController < ApplicationController
      def index
        @recent_upgrades = load_recent_upgrades
        @suggested_upgrades = detect_suggested_upgrades
      end
      
      def create
        @instruction = params[:instruction].to_s.strip
        
        if @instruction.blank?
          render json: { error: 'Upgrade instruction cannot be blank' }, status: :bad_request
          return
        end
        
        begin
          result = generate_upgrade_plan(@instruction)
          
          # Log the upgrade request
          log_prompt(@instruction, result[:response], {
            type: 'upgrade',
            estimated_changes: result[:estimated_changes] || 0
          })
          
          render json: {
            success: true,
            plan: result[:plan],
            changes: result[:changes],
            estimated_time: result[:estimated_time],
            warnings: result[:warnings],
            explanation: result[:explanation]
          }
        rescue => e
          Rails.logger.error "Upgrade planning failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Upgrade planning failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def preview
        @instruction = params[:instruction].to_s.strip
        
        if @instruction.blank?
          render json: { error: 'Instruction required' }, status: :bad_request
          return
        end
        
        begin
          preview_result = generate_upgrade_preview(@instruction)
          
          render json: {
            success: true,
            preview: preview_result[:preview],
            affected_files: preview_result[:affected_files],
            risk_level: preview_result[:risk_level],
            backup_recommended: preview_result[:backup_recommended]
          }
        rescue => e
          Rails.logger.error "Upgrade preview failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Preview failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def apply
        changes_data = params[:changes]
        dry_run = params[:dry_run] == 'true'
        
        if changes_data.blank?
          render json: { error: 'No changes to apply' }, status: :bad_request
          return
        end
        
        begin
          result = apply_upgrade_changes(changes_data, dry_run)
          
          # Log the upgrade application
          log_prompt("APPLY UPGRADE", result, {
            type: 'upgrade_apply',
            dry_run: dry_run,
            files_changed: result[:files_changed] || 0
          })
          
          render json: {
            success: result[:success],
            message: result[:message],
            files_changed: result[:files_changed],
            backup_location: result[:backup_location]
          }
        rescue => e
          Rails.logger.error "Upgrade application failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Application failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def load_recent_upgrades
        return [] unless File.exist?(prompt_logger)
        
        upgrades = []
        File.readlines(prompt_logger).each do |line|
          entry = JSON.parse(line.strip)
          if entry['metadata'] && entry['metadata']['type']&.start_with?('upgrade')
            upgrades << entry
          end
        rescue JSON::ParserError
          next
        end
        upgrades.reverse.first(10)
      end
      
      def detect_suggested_upgrades
        suggestions = []
        
        # Ruby version upgrade
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.2.0')
          suggestions << {
            title: 'Upgrade Ruby Version',
            description: "Current: #{RUBY_VERSION}, Recommended: 3.2+",
            priority: 'medium',
            type: 'ruby_upgrade'
          }
        end
        
        # Rails version upgrade
        if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new('7.1.0')
          suggestions << {
            title: 'Upgrade Rails Version',
            description: "Current: #{Rails::VERSION::STRING}, Recommended: 7.1+",
            priority: 'medium',
            type: 'rails_upgrade'
          }
        end
        
        # Context-based suggestions
        if @app_context && @app_context['models']
          # Suggest enum upgrades if old-style enums are detected
          old_enums = detect_old_style_enums
          if old_enums.any?
            suggestions << {
              title: 'Convert to Native Postgres Enums',
              description: "Found #{old_enums.length} models with integer enums that could be converted",
              priority: 'low',
              type: 'enum_upgrade'
            }
          end
          
          # Suggest Hotwire upgrades if using old UJS
          if detect_ujs_usage
            suggestions << {
              title: 'Migrate from UJS to Hotwire',
              description: 'Replace Rails UJS with modern Hotwire Turbo and Stimulus',
              priority: 'high',
              type: 'hotwire_upgrade'
            }
          end
        end
        
        # Security upgrades
        security_suggestions = detect_security_upgrades
        suggestions.concat(security_suggestions)
        
        suggestions
      end
      
      def detect_old_style_enums
        return [] unless @app_context && @app_context['models']
        
        models_with_enums = []
        @app_context['models'].each do |model|
          # Look for enum-like attributes (this is a simplified check)
          validations = model['validations'] || []
          if validations.any? { |v| v['rules']&.include?('inclusion') }
            models_with_enums << model['class_name']
          end
        end
        models_with_enums
      end
      
      def detect_ujs_usage
        # Check for UJS usage in application files
        js_files = Dir.glob(Rails.root.join('app/assets/javascripts/**/*.js'))
        js_files.any? do |file|
          File.read(file).include?('rails-ujs') || File.read(file).include?('jquery_ujs')
        end
      rescue
        false
      end
      
      def detect_security_upgrades
        suggestions = []
        
        # Check for missing security headers
        if !File.exist?(Rails.root.join('config/initializers/content_security_policy.rb'))
          suggestions << {
            title: 'Add Content Security Policy',
            description: 'Implement CSP headers for better security',
            priority: 'medium',
            type: 'security_csp'
          }
        end
        
        # Check for HTTPS enforcement
        production_config = Rails.root.join('config/environments/production.rb')
        if File.exist?(production_config) && !File.read(production_config).include?('force_ssl')
          suggestions << {
            title: 'Enable HTTPS Enforcement',
            description: 'Force SSL in production for security',
            priority: 'high',
            type: 'security_ssl'
          }
        end
        
        suggestions
      end
      
      def generate_upgrade_plan(instruction)
        # Analyze the instruction and create upgrade plan
        instruction_lower = instruction.downcase
        
        plan = {
          phases: [],
          estimated_time: estimate_upgrade_time(instruction),
          risk_level: assess_risk_level(instruction),
          backup_recommended: true
        }
        
        changes = []
        warnings = []
        
        if instruction_lower.include?('enum') && instruction_lower.include?('postgres')
          plan[:phases] << generate_enum_upgrade_plan
          changes.concat(generate_enum_changes)
        elsif instruction_lower.include?('hotwire') || instruction_lower.include?('turbo')
          plan[:phases] << generate_hotwire_upgrade_plan
          changes.concat(generate_hotwire_changes)
        elsif instruction_lower.include?('ruby')
          plan[:phases] << generate_ruby_upgrade_plan
          warnings << "Ruby upgrades require manual intervention outside of Rails"
        elsif instruction_lower.include?('rails')
          plan[:phases] << generate_rails_upgrade_plan
          warnings << "Rails upgrades should be done incrementally"
        else
          # Generic upgrade planning using AI if available
          if defined?(RailsPlan::AI) && ai_config&.configured?
            ai_plan = generate_ai_upgrade_plan(instruction)
            plan = ai_plan[:plan] if ai_plan[:plan]
            changes = ai_plan[:changes] if ai_plan[:changes]
          else
            plan[:phases] << {
              name: 'Analysis',
              description: 'Manual analysis required for this upgrade',
              steps: ['Review the upgrade requirements', 'Plan the implementation', 'Test thoroughly']
            }
          end
        end
        
        {
          plan: plan,
          changes: changes,
          estimated_time: plan[:estimated_time],
          warnings: warnings,
          explanation: generate_upgrade_explanation(instruction, plan),
          response: { plan: plan, changes: changes },
          estimated_changes: changes.length
        }
      end
      
      def generate_enum_upgrade_plan
        {
          name: 'Convert Integer Enums to Postgres Native Enums',
          description: 'Migrate from Rails integer enums to Postgres ENUM types',
          steps: [
            'Create Postgres ENUM types via migration',
            'Update model definitions to use string enums',
            'Create data migration to convert existing records',
            'Update any queries that reference integer values',
            'Test enum functionality thoroughly'
          ],
          estimated_time: '2-4 hours'
        }
      end
      
      def generate_hotwire_upgrade_plan
        {
          name: 'Migrate from UJS to Hotwire',
          description: 'Replace Rails UJS with Hotwire Turbo and Stimulus',
          steps: [
            'Remove rails-ujs from application.js',
            'Add Hotwire Turbo and Stimulus',
            'Convert remote: true forms to turbo_stream',
            'Replace UJS confirm dialogs with Turbo confirmations',
            'Convert AJAX calls to Turbo Frame requests',
            'Add Stimulus controllers for interactive behaviors'
          ],
          estimated_time: '4-8 hours'
        }
      end
      
      def generate_ruby_upgrade_plan
        {
          name: 'Ruby Version Upgrade',
          description: 'Upgrade Ruby to a newer version',
          steps: [
            'Update .ruby-version file',
            'Update Gemfile ruby declaration',
            'Run bundle install',
            'Fix any deprecated syntax',
            'Update CI/CD configurations',
            'Test thoroughly'
          ],
          estimated_time: '1-3 hours'
        }
      end
      
      def generate_rails_upgrade_plan
        {
          name: 'Rails Version Upgrade',
          description: 'Upgrade Rails to a newer version',
          steps: [
            'Update Rails version in Gemfile',
            'Run bundle update rails',
            'Run rails app:update',
            'Review and merge configuration changes',
            'Fix deprecation warnings',
            'Update dependencies',
            'Run full test suite'
          ],
          estimated_time: '4-12 hours'
        }
      end
      
      def generate_enum_changes
        [
          {
            type: 'migration',
            file: 'db/migrate/add_enum_types.rb',
            action: 'create',
            description: 'Create Postgres ENUM types'
          },
          {
            type: 'migration',
            file: 'db/migrate/convert_enum_data.rb',
            action: 'create',
            description: 'Convert existing enum data'
          }
        ]
      end
      
      def generate_hotwire_changes
        [
          {
            type: 'javascript',
            file: 'app/javascript/application.js',
            action: 'modify',
            description: 'Replace UJS with Hotwire imports'
          },
          {
            type: 'view',
            file: 'app/views/layouts/application.html.erb',
            action: 'modify',
            description: 'Update layout for Turbo'
          }
        ]
      end
      
      def estimate_upgrade_time(instruction)
        instruction_lower = instruction.downcase
        
        if instruction_lower.include?('rails') && instruction_lower.include?('major')
          '8-16 hours'
        elsif instruction_lower.include?('ruby')
          '2-6 hours'
        elsif instruction_lower.include?('hotwire')
          '4-8 hours'
        elsif instruction_lower.include?('enum')
          '2-4 hours'
        else
          '1-4 hours'
        end
      end
      
      def assess_risk_level(instruction)
        instruction_lower = instruction.downcase
        
        if instruction_lower.include?('rails') || instruction_lower.include?('ruby')
          'high'
        elsif instruction_lower.include?('database') || instruction_lower.include?('migration')
          'medium'
        else
          'low'
        end
      end
      
      def generate_upgrade_explanation(instruction, plan)
        "Based on your request to #{instruction.downcase}, I've created a #{plan[:phases].length}-phase upgrade plan. " \
        "This is estimated to take #{plan[:estimated_time]} and has a #{plan[:risk_level]} risk level. " \
        "#{plan[:backup_recommended] ? 'I strongly recommend creating a backup before proceeding.' : ''}"
      end
      
      def generate_upgrade_preview(instruction)
        # Generate a preview of what the upgrade would do
        {
          preview: "Preview for: #{instruction}",
          affected_files: estimate_affected_files(instruction),
          risk_level: assess_risk_level(instruction),
          backup_recommended: true
        }
      end
      
      def estimate_affected_files(instruction)
        instruction_lower = instruction.downcase
        
        if instruction_lower.include?('rails')
          ['Gemfile', 'config/**/*.rb', 'app/**/*.rb', 'db/migrate/*.rb']
        elsif instruction_lower.include?('hotwire')
          ['app/javascript/**/*.js', 'app/views/**/*.erb', 'Gemfile']
        elsif instruction_lower.include?('enum')
          ['app/models/*.rb', 'db/migrate/*.rb']
        else
          ['Various files based on upgrade scope']
        end
      end
      
      def apply_upgrade_changes(changes_data, dry_run)
        if dry_run
          return {
            success: true,
            message: 'Dry run completed successfully',
            files_changed: changes_data.length,
            backup_location: nil
          }
        end
        
        # For now, save changes to .railsplan/ui directory
        ui_dir = Rails.root.join('.railsplan', 'ui', 'upgrades')
        FileUtils.mkdir_p(ui_dir)
        
        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        backup_dir = ui_dir.join("backup_#{timestamp}")
        FileUtils.mkdir_p(backup_dir)
        
        applied_files = 0
        changes_data.each_with_index do |change, index|
          change_file = backup_dir.join("change_#{index + 1}.txt")
          File.write(change_file, change.to_json)
          applied_files += 1
        end
        
        {
          success: true,
          message: "Upgrade changes saved to backup directory (dry run mode)",
          files_changed: applied_files,
          backup_location: backup_dir.to_s
        }
      end
      
      def generate_ai_upgrade_plan(instruction)
        # Use AI to generate upgrade plan if available
        # This would integrate with the existing RailsPlan::AI system
        {
          plan: {
            phases: [{
              name: 'AI-Generated Upgrade Plan',
              description: 'Custom upgrade plan generated by AI',
              steps: ['Analyze requirements', 'Implement changes', 'Test thoroughly']
            }],
            estimated_time: '2-6 hours',
            risk_level: 'medium',
            backup_recommended: true
          },
          changes: []
        }
      end
    end
  end
end