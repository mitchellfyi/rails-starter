# frozen_string_literal: true

module Railsplan
  module Web
    class DoctorController < ApplicationController
      def index
        @diagnostics = run_diagnostics
        @recent_runs = load_recent_doctor_runs
        @available_fixes = detect_available_fixes(@diagnostics)
      end
      
      def run
        begin
          @diagnostics = run_comprehensive_diagnostics
          
          # Log the doctor run
          log_prompt("RUN DOCTOR", @diagnostics, {
            type: 'doctor',
            issues_found: @diagnostics.count { |d| d[:level] == 'error' || d[:level] == 'warning' }
          })
          
          render json: {
            success: true,
            diagnostics: @diagnostics,
            summary: generate_diagnostics_summary(@diagnostics)
          }
        rescue => e
          Rails.logger.error "Doctor run failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Doctor run failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def fix
        issue_type = params[:issue_type]
        
        if issue_type.blank?
          render json: { error: 'Issue type required' }, status: :bad_request
          return
        end
        
        begin
          result = apply_automatic_fix(issue_type)
          
          # Log the fix attempt
          log_prompt("AUTO FIX: #{issue_type}", result, {
            type: 'fix',
            issue_type: issue_type
          })
          
          render json: {
            success: result[:success],
            message: result[:message],
            details: result[:details]
          }
        rescue => e
          Rails.logger.error "Auto fix failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Fix failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def run_diagnostics
        diagnostics = []
        
        # Ruby and Rails version checks
        diagnostics.concat(check_ruby_rails_versions)
        
        # Context and configuration checks
        diagnostics.concat(check_context_status)
        
        # AI configuration checks
        diagnostics.concat(check_ai_configuration)
        
        # Database checks
        diagnostics.concat(check_database_status)
        
        # File structure checks
        diagnostics.concat(check_file_structure)
        
        # Security checks
        diagnostics.concat(check_security_basics)
        
        diagnostics
      end
      
      def run_comprehensive_diagnostics
        # More thorough diagnostics including AI-powered analysis
        diagnostics = run_diagnostics
        
        # Add performance checks
        diagnostics.concat(check_performance_issues)
        
        # Add code quality checks
        diagnostics.concat(check_code_quality)
        
        diagnostics
      end
      
      def check_ruby_rails_versions
        checks = []
        
        # Ruby version check
        ruby_version = RUBY_VERSION
        if Gem::Version.new(ruby_version) < Gem::Version.new('3.0.0')
          checks << {
            category: 'Version',
            title: 'Outdated Ruby Version',
            description: "Ruby #{ruby_version} is outdated. Consider upgrading to 3.0+",
            level: 'warning',
            fixable: false
          }
        else
          checks << {
            category: 'Version',
            title: 'Ruby Version',
            description: "Ruby #{ruby_version} ✓",
            level: 'success',
            fixable: false
          }
        end
        
        # Rails version check
        rails_version = Rails::VERSION::STRING
        if Gem::Version.new(rails_version) < Gem::Version.new('7.0.0')
          checks << {
            category: 'Version',
            title: 'Outdated Rails Version',
            description: "Rails #{rails_version} is outdated. Consider upgrading to 7.0+",
            level: 'warning',
            fixable: false
          }
        else
          checks << {
            category: 'Version',
            title: 'Rails Version',
            description: "Rails #{rails_version} ✓",
            level: 'success',
            fixable: false
          }
        end
        
        checks
      end
      
      def check_context_status
        checks = []
        
        if @app_context.nil?
          checks << {
            category: 'Context',
            title: 'Missing Application Context',
            description: 'Run "railsplan index" to extract application context',
            level: 'error',
            fixable: true,
            fix_command: 'railsplan index'
          }
        elsif !context_is_fresh?
          checks << {
            category: 'Context',
            title: 'Stale Application Context',
            description: 'Context is outdated. Run "railsplan index" to refresh',
            level: 'warning',
            fixable: true,
            fix_command: 'railsplan index'
          }
        else
          checks << {
            category: 'Context',
            title: 'Application Context',
            description: 'Context is fresh and up-to-date ✓',
            level: 'success',
            fixable: false
          }
        end
        
        checks
      end
      
      def check_ai_configuration
        checks = []
        
        config = ai_config
        if config.nil? || !config.configured?
          checks << {
            category: 'AI',
            title: 'AI Not Configured',
            description: 'Configure AI providers in ~/.railsplan/ai.yml for AI features',
            level: 'warning',
            fixable: false
          }
        else
          checks << {
            category: 'AI',
            title: 'AI Configuration',
            description: 'AI providers configured ✓',
            level: 'success',
            fixable: false
          }
        end
        
        checks
      end
      
      def check_database_status
        checks = []
        
        begin
          if defined?(ActiveRecord)
            ActiveRecord::Base.connection.execute('SELECT 1')
            checks << {
              category: 'Database',
              title: 'Database Connection',
              description: "Connected to #{ActiveRecord::Base.connection.adapter_name} ✓",
              level: 'success',
              fixable: false
            }
          else
            checks << {
              category: 'Database',
              title: 'Database',
              description: 'ActiveRecord not available',
              level: 'info',
              fixable: false
            }
          end
        rescue => e
          checks << {
            category: 'Database',
            title: 'Database Connection Failed',
            description: "Cannot connect to database: #{e.message}",
            level: 'error',
            fixable: false
          }
        end
        
        checks
      end
      
      def check_file_structure
        checks = []
        
        # Check for essential Rails directories
        essential_dirs = ['app/models', 'app/controllers', 'app/views', 'config', 'db']
        
        essential_dirs.each do |dir|
          if Dir.exist?(Rails.root.join(dir))
            checks << {
              category: 'Structure',
              title: "#{dir} Directory",
              description: "#{dir} exists ✓",
              level: 'success',
              fixable: false
            }
          else
            checks << {
              category: 'Structure',
              title: "Missing #{dir}",
              description: "Essential directory #{dir} is missing",
              level: 'error',
              fixable: false
            }
          end
        end
        
        checks
      end
      
      def check_security_basics
        checks = []
        
        # Check for common security files
        if File.exist?(Rails.root.join('config/credentials.yml.enc'))
          checks << {
            category: 'Security',
            title: 'Encrypted Credentials',
            description: 'Rails credentials file found ✓',
            level: 'success',
            fixable: false
          }
        else
          checks << {
            category: 'Security',
            title: 'No Encrypted Credentials',
            description: 'Consider using Rails encrypted credentials',
            level: 'info',
            fixable: false
          }
        end
        
        checks
      end
      
      def check_performance_issues
        checks = []
        
        # Check for N+1 query potential (basic check)
        if @app_context && @app_context['models']
          models_with_associations = @app_context['models'].select do |model|
            (model['associations'] || []).any?
          end
          
          if models_with_associations.any?
            checks << {
              category: 'Performance',
              title: 'Potential N+1 Queries',
              description: "#{models_with_associations.length} models have associations. Review for N+1 queries",
              level: 'info',
              fixable: false
            }
          end
        end
        
        checks
      end
      
      def check_code_quality
        checks = []
        
        # Check for test files
        test_dirs = ['test', 'spec']
        has_tests = test_dirs.any? { |dir| Dir.exist?(Rails.root.join(dir)) && Dir.glob(Rails.root.join(dir, '**/*_test.rb')).any? }
        
        if has_tests
          checks << {
            category: 'Quality',
            title: 'Tests Present',
            description: 'Test files found ✓',
            level: 'success',
            fixable: false
          }
        else
          checks << {
            category: 'Quality',
            title: 'No Tests Found',
            description: 'Consider adding tests for better code quality',
            level: 'warning',
            fixable: false
          }
        end
        
        checks
      end
      
      def context_is_fresh?
        return false unless @app_context
        
        context_time = Time.parse(@app_context['generated_at'])
        context_time > 1.hour.ago
      rescue
        false
      end
      
      def load_recent_doctor_runs
        return [] unless File.exist?(prompt_logger)
        
        runs = []
        File.readlines(prompt_logger).each do |line|
          entry = JSON.parse(line.strip)
          if entry['metadata'] && entry['metadata']['type'] == 'doctor'
            runs << entry
          end
        rescue JSON::ParserError
          next
        end
        runs.reverse.first(5)
      end
      
      def detect_available_fixes(diagnostics)
        diagnostics.select { |d| d[:fixable] }.map { |d| d[:fix_command] }.compact.uniq
      end
      
      def generate_diagnostics_summary(diagnostics)
        summary = {
          total: diagnostics.length,
          errors: diagnostics.count { |d| d[:level] == 'error' },
          warnings: diagnostics.count { |d| d[:level] == 'warning' },
          successes: diagnostics.count { |d| d[:level] == 'success' },
          infos: diagnostics.count { |d| d[:level] == 'info' }
        }
        
        if summary[:errors] > 0
          summary[:status] = 'critical'
          summary[:message] = "#{summary[:errors]} critical issues found"
        elsif summary[:warnings] > 0
          summary[:status] = 'warning'
          summary[:message] = "#{summary[:warnings]} warnings found"
        else
          summary[:status] = 'healthy'
          summary[:message] = 'All checks passed'
        end
        
        summary
      end
      
      def apply_automatic_fix(issue_type)
        case issue_type
        when 'stale_context'
          {
            success: false,
            message: 'Please run "railsplan index" in your terminal to refresh context',
            details: 'Context refresh requires CLI command'
          }
        when 'missing_context'
          {
            success: false,
            message: 'Please run "railsplan index" in your terminal to create context',
            details: 'Context creation requires CLI command'
          }
        else
          {
            success: false,
            message: "No automatic fix available for #{issue_type}",
            details: 'Manual intervention required'
          }
        end
      end
    end
  end
end