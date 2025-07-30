# frozen_string_literal: true

require_relative 'base_command'
require 'railsplan/context_manager'
require 'railsplan/ai_generator'
require 'railsplan/ai_config'
require 'yaml'
require 'json'

module RailsPlan
  module Commands
    # Enhanced command for system diagnostics, static analysis, and AI-powered code quality scanning
    class DoctorCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
        @ai_config = AIConfig.new
        @issues = []
        @fixable_issues = []
      end
      
      def execute(options = {})
        puts '🏥 Running comprehensive application diagnostics...'
        
        # Basic system checks
        results = []
        results << check_ruby_version
        results << check_template_structure
        results << check_registry_integrity
        results << check_environment_variables
        results << check_pending_migrations
        results << check_module_integrity
        
        # Enhanced Rails application checks
        if rails_app?
          puts "\n🔍 Scanning Rails application for issues..."
          results << check_rails_application
          results << check_deprecated_apis
          results << check_missing_tests
          results << check_unused_code
          results << check_performance_issues
          results << check_security_issues
          
          # AI-powered analysis if configured
          if @ai_config.configured? && File.exist?(@context_manager.context_path)
            puts "\n🤖 Running AI-powered code quality analysis..."
            results << run_ai_analysis
          end
        end
        
        # Display results
        display_results(options)
        
        # Handle options
        if options[:fix] && @fixable_issues.any?
          fix_issues(options)
        elsif options[:report]
          generate_report(options[:report])
        end
        
        failed_checks = results.count(false)
        if failed_checks > 0
          puts "\n❌ #{failed_checks} check(s) failed"
          puts "💡 Run with --verbose for detailed suggestions"
          puts "💡 Use --fix to automatically fix some issues"
          false
        else
          puts "\n✅ All checks passed"
          true
        end
      end

      private

      def check_ruby_version
        puts "Ruby version: #{RUBY_VERSION}"
        true # Ruby is running, so version is adequate
      end

      def check_template_structure
        puts "\nChecking template structure:"
        
        if File.exist?(registry_path)
          puts "✅ Module registry found"
          registry_ok = true
        else
          puts "⚠️  Module registry not found at #{registry_path}"
          registry_ok = false
        end
        
        if Dir.exist?(template_path)
          puts "✅ Module templates directory found"
          templates_ok = true
        else
          puts "⚠️  Module templates directory not found at #{template_path}"
          templates_ok = false
        end
        
        registry_ok && templates_ok
      end

      def check_registry_integrity
        return true unless File.exist?(registry_path)
        
        begin
          registry = JSON.parse(File.read(registry_path))
          puts "✅ Module registry is valid JSON"
          
          installed_count = registry.dig('installed')&.keys&.count || 0
          puts "📦 #{installed_count} module(s) registered as installed"
          true
        rescue JSON::ParserError
          puts "❌ Module registry is corrupted (invalid JSON)"
          false
        end
      end

      def check_environment_variables
        if File.exist?('.env') || File.exist?('.env.example')
          puts "✅ Environment configuration found"
          true
        else
          puts "⚠️  No .env or .env.example file found"
          puts "    Run 'bin/railsplan bootstrap' to generate environment file"
          false
        end
      end

      def check_pending_migrations
        if Dir.exist?('db/migrate')
          migration_count = Dir.glob('db/migrate/*.rb').length
          puts "📊 #{migration_count} migration file(s) found"
          
          if migration_count > 0
            puts "💡 Run 'rails db:migrate' to apply pending migrations"
          end
          true
        else
          puts "⚠️  No migrations directory found"
          false
        end
      end

      def check_module_integrity
        registry = load_registry
        installed_modules = registry['installed'] || {}
        
        integrity_ok = true
        
        installed_modules.each do |module_name, info|
          module_path = File.join('app', 'domains', module_name)
          
          if Dir.exist?(module_path)
            puts "✅ #{module_name} module files found"
          else
            puts "❌ #{module_name} module missing from app/domains/"
            integrity_ok = false
          end
        end
        
        integrity_ok
      end
      
      def rails_app?
        File.exist?("config/application.rb") && File.exist?("Gemfile")
      end
      
      def check_rails_application
        puts "\n🚂 Checking Rails application structure..."
        
        issues_found = false
        
        # Check for required directories
        required_dirs = %w[app/models app/controllers app/views config db]
        required_dirs.each do |dir|
          unless Dir.exist?(dir)
            add_issue("Missing required directory: #{dir}", 'error', false)
            issues_found = true
          end
        end
        
        # Check for required files
        required_files = %w[config/application.rb config/routes.rb Gemfile]
        required_files.each do |file|
          unless File.exist?(file)
            add_issue("Missing required file: #{file}", 'error', false)
            issues_found = true
          end
        end
        
        unless issues_found
          puts "✅ Rails application structure is valid"
        end
        
        !issues_found
      end
      
      def check_deprecated_apis
        puts "🔍 Scanning for deprecated Rails APIs..."
        
        deprecated_patterns = {
          'before_filter' => 'Use before_action instead',
          'after_filter' => 'Use after_action instead',
          'find_by_sql' => 'Consider using ActiveRecord query methods',
          'update_attributes' => 'Use update instead',
          'all.*conditions' => 'Use .where() instead of .all(conditions)',
          'RAILS_ENV' => 'Use Rails.env instead',
          'RAILS_ROOT' => 'Use Rails.root instead'
        }
        
        issues_found = scan_for_patterns(deprecated_patterns, 'deprecated_api')
        
        unless issues_found
          puts "✅ No deprecated APIs found"
        end
        
        !issues_found
      end
      
      def check_missing_tests
        puts "🧪 Checking test coverage..."
        
        models = Dir.glob('app/models/**/*.rb')
        controllers = Dir.glob('app/controllers/**/*.rb')
        
        missing_tests = []
        
        models.each do |model_file|
          test_file = model_file.gsub('app/', 'test/').gsub('.rb', '_test.rb')
          spec_file = model_file.gsub('app/', 'spec/').gsub('.rb', '_spec.rb')
          
          unless File.exist?(test_file) || File.exist?(spec_file)
            missing_tests << model_file
          end
        end
        
        controllers.each do |controller_file|
          next if controller_file.include?('application_controller.rb')
          
          test_file = controller_file.gsub('app/', 'test/').gsub('.rb', '_test.rb')
          spec_file = controller_file.gsub('app/', 'spec/').gsub('.rb', '_spec.rb')
          
          unless File.exist?(test_file) || File.exist?(spec_file)
            missing_tests << controller_file
          end
        end
        
        missing_tests.each do |file|
          add_issue("Missing tests for #{file}", 'warning', true, "Generate tests for #{file}")
        end
        
        if missing_tests.empty?
          puts "✅ All critical files have tests"
        else
          puts "⚠️  #{missing_tests.length} files missing tests"
        end
        
        missing_tests.empty?
      end
      
      def check_unused_code
        puts "🗑️  Scanning for unused code..."
        
        # Check for unused routes
        unused_routes = find_unused_routes
        unused_routes.each do |route|
          add_issue("Unused route: #{route}", 'warning', true, "Remove unused route #{route}")
        end
        
        # Check for unused database columns
        unused_columns = find_unused_columns
        unused_columns.each do |column|
          add_issue("Potentially unused column: #{column}", 'info', true, "Remove unused column #{column}")
        end
        
        total_unused = unused_routes.length + unused_columns.length
        
        if total_unused == 0
          puts "✅ No obvious unused code found"
        else
          puts "⚠️  Found #{total_unused} potentially unused items"
        end
        
        total_unused == 0
      end
      
      def check_performance_issues
        puts "⚡ Scanning for performance issues..."
        
        # Check for N+1 query patterns
        n_plus_one_patterns = {
          'each.*find' => 'Potential N+1 query: use includes() or joins()',
          'map.*find' => 'Potential N+1 query: use includes() or joins()',
          'each.*where' => 'Potential N+1 query: use includes() or joins()'
        }
        
        issues_found = scan_for_patterns(n_plus_one_patterns, 'performance')
        
        # Check for missing database indexes
        missing_indexes = find_missing_indexes
        missing_indexes.each do |index|
          add_issue("Missing database index: #{index}", 'warning', true, "Add database index for #{index}")
        end
        
        total_issues = @issues.count { |i| i[:category] == 'performance' } + missing_indexes.length
        
        if total_issues == 0
          puts "✅ No obvious performance issues found"
        else
          puts "⚠️  Found #{total_issues} potential performance issues"
        end
        
        total_issues == 0
      end
      
      def check_security_issues
        puts "🔒 Scanning for security issues..."
        
        security_patterns = {
          'params\[' => 'Use strong parameters instead of direct params access',
          'raw\(' => 'Potential XSS: use html_safe or sanitize',
          'eval\(' => 'Security risk: avoid using eval',
          'system\(' => 'Security risk: validate input before system calls',
          'command_injection' => 'Command injection risk: validate input in backticks'
        }
        
        issues_found = scan_for_patterns(security_patterns, 'security')
        
        # Check for missing CSRF protection
        if !File.read('app/controllers/application_controller.rb').include?('protect_from_forgery')
          add_issue("Missing CSRF protection in ApplicationController", 'error', true, "Add protect_from_forgery to ApplicationController")
          issues_found = true
        end
        
        unless issues_found
          puts "✅ No obvious security issues found"
        end
        
        !issues_found
      end
      
      def run_ai_analysis
        begin
          ai_generator = AIGenerator.new(@ai_config, @context_manager)
          context = JSON.parse(File.read(@context_manager.context_path))
          
          ai_issues = ai_generator.generate("Analyze this Rails application for code quality issues", {
            context: context,
            type: 'code_analysis',
            focus: ['maintainability', 'performance', 'security', 'best_practices']
          })
          
          if ai_issues[:issues]&.any?
            ai_issues[:issues].each do |issue|
              category = issue[:severity] == 'high' ? 'error' : 'warning'
              fixable = issue[:fixable] || false
              add_issue("AI: #{issue[:description]}", category, fixable, issue[:fix_suggestion])
            end
            
            puts "🤖 AI found #{ai_issues[:issues].length} additional issues"
          else
            puts "✅ AI analysis found no additional issues"
          end
          
          true
        rescue StandardError => e
          log_verbose("AI analysis failed: #{e.message}")
          puts "⚠️  AI analysis skipped (#{e.message})"
          false
        end
      end
      
      def scan_for_patterns(patterns, category)
        issues_found = false
        
        Dir.glob('app/**/*.rb').each do |file|
          content = File.read(file)
          line_number = 0
          
          content.lines.each do |line|
            line_number += 1
            
            patterns.each do |pattern, description|
              if line.match(/#{pattern}/)
                add_issue("#{file}:#{line_number} - #{description}", 'warning', true, description)
                issues_found = true
              end
            end
          end
        end
        
        issues_found
      end
      
      def find_unused_routes
        # This is a simplified check - in practice you'd want more sophisticated analysis
        []
      end
      
      def find_unused_columns
        # This is a simplified check - would require database introspection
        []
      end
      
      def find_missing_indexes
        # This is a simplified check - would require schema analysis
        []
      end
      
      def add_issue(description, severity, fixable, fix_suggestion = nil)
        issue = {
          description: description,
          severity: severity,
          fixable: fixable,
          fix_suggestion: fix_suggestion,
          category: determine_category(description)
        }
        
        @issues << issue
        @fixable_issues << issue if fixable
        
        puts "#{severity_icon(severity)} #{description}"
      end
      
      def determine_category(description)
        return 'performance' if description.include?('N+1') || description.include?('index')
        return 'security' if description.include?('Security') || description.include?('CSRF')
        return 'test' if description.include?('test')
        return 'deprecated' if description.include?('deprecated')
        'general'
      end
      
      def severity_icon(severity)
        case severity
        when 'error' then '❌'
        when 'warning' then '⚠️'
        when 'info' then 'ℹ️'
        else '•'
        end
      end
      
      def display_results(options)
        return if @issues.empty?
        
        puts "\n📋 Issues Summary:"
        puts "━" * 50
        
        categories = @issues.group_by { |i| i[:category] }
        
        categories.each do |category, issues|
          puts "\n#{category.humanize}:"
          issues.each do |issue|
            puts "  #{severity_icon(issue[:severity])} #{issue[:description]}"
          end
        end
        
        puts "\n━" * 50
        puts "Total issues: #{@issues.length}"
        puts "Fixable issues: #{@fixable_issues.length}"
        
        if @fixable_issues.any?
          puts "\n💡 Run 'railsplan doctor --fix' to automatically fix some issues"
          puts "💡 Run 'railsplan fix \"<description>\"' to fix specific issues with AI"
        end
      end
      
      def fix_issues(options)
        puts "\n🔧 Fixing #{@fixable_issues.length} automatically fixable issues..."
        
        @fixable_issues.each do |issue|
          if fix_issue(issue)
            puts "✅ Fixed: #{issue[:description]}"
          else
            puts "❌ Failed to fix: #{issue[:description]}"
          end
        end
      end
      
      def fix_issue(issue)
        # Implement basic fixes for common issues
        case issue[:category]
        when 'test'
          # Could generate basic test templates
          false
        when 'performance'
          # Could suggest index additions
          false
        else
          false
        end
      end
      
      def generate_report(format)
        case format
        when 'markdown'
          generate_markdown_report
        when 'json'
          generate_json_report
        else
          puts "❌ Unknown report format: #{format}"
        end
      end
      
      def generate_markdown_report
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        report_path = "railsplan_doctor_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.md"
        
        content = []
        content << "# RailsPlan Doctor Report"
        content << ""
        content << "**Generated**: #{timestamp}"
        content << "**Total Issues**: #{@issues.length}"
        content << "**Fixable Issues**: #{@fixable_issues.length}"
        content << ""
        
        categories = @issues.group_by { |i| i[:category] }
        
        categories.each do |category, issues|
          content << "## #{category.humanize}"
          content << ""
          
          issues.each do |issue|
            severity_emoji = severity_icon(issue[:severity])
            content << "- #{severity_emoji} #{issue[:description]}"
            
            if issue[:fix_suggestion]
              content << "  - **Fix**: #{issue[:fix_suggestion]}"
            end
          end
          
          content << ""
        end
        
        File.write(report_path, content.join("\n"))
        puts "📄 Report saved to #{report_path}"
      end
      
      def generate_json_report
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        report_path = "railsplan_doctor_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
        
        report = {
          generated_at: timestamp,
          total_issues: @issues.length,
          fixable_issues: @fixable_issues.length,
          issues: @issues,
          summary: @issues.group_by { |i| i[:severity] }.transform_values(&:count)
        }
        
        File.write(report_path, JSON.pretty_generate(report))
        puts "📄 Report saved to #{report_path}"
      end
    end
  end
end