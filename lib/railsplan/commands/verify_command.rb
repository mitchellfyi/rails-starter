# frozen_string_literal: true

require_relative 'base_command'
require 'json'
require 'fileutils'
require 'digest'

module RailsPlan
  module Commands
    # Command for CI verification of railsplan app integrity
    class VerifyCommand < BaseCommand
      def execute(options = {})
        ci_mode = options[:ci] || false
        
        if ci_mode
          puts '🔍 Running railsplan CI verification...'
        else
          puts '🔍 Running railsplan verification...'
        end
        
        results = []
        results << verify_context_freshness
        results << verify_no_undocumented_diffs
        results << verify_prompt_logs_consistency
        results << verify_test_coverage_for_generated_code
        results << verify_module_configurations
        
        # Additional CI-specific verifications
        if ci_mode
          results << verify_no_stale_artifacts
          results << verify_environment_consistency
        end
        
        puts "\n🔍 Verification complete"
        
        failed_verifications = results.count(false)
        if failed_verifications > 0
          puts "❌ #{failed_verifications} verification(s) failed"
          puts "\n💡 Run with --verbose for detailed information"
          
          # Generate CI verification report
          if ci_mode
            generate_verification_report(results, failed_verifications)
          end
          
          false
        else
          puts "✅ All verifications passed"
          
          # Generate successful verification report for CI
          if ci_mode
            generate_verification_report(results, failed_verifications)
          end
          
          true
        end
      end

      private

      def verify_context_freshness
        puts "\nVerifying railsplan context freshness:"
        
        context_file = '.railsplan/context.json'
        unless File.exist?(context_file)
          puts "❌ No railsplan context found - run 'railsplan index' first"
          return false
        end
        
        begin
          context = JSON.parse(File.read(context_file))
          
          # Check if context hash matches current app state
          current_hash = calculate_app_state_hash
          stored_hash = context['hash']
          
          if current_hash == stored_hash
            puts "✅ railsplan context is up to date"
            true
          else
            puts "❌ railsplan context is stale - app has changed since last indexing"
            puts "   Run 'railsplan index' to update the context"
            false
          end
        rescue JSON::ParserError
          puts "❌ railsplan context file is corrupted"
          false
        rescue => e
          puts "❌ Error verifying context: #{e.message}"
          false
        end
      end

      def verify_no_undocumented_diffs
        puts "\nVerifying no undocumented diffs:"
        
        # Check if there are any generated files that have been modified
        # but not documented in the generation log
        last_generated_dir = '.railsplan/last_generated'
        
        unless Dir.exist?(last_generated_dir)
          puts "✅ No generation history to check"
          return true
        end
        
        # Look for files that were generated but have uncommitted changes
        uncommitted_generated_files = []
        
        if Dir.exist?('.git')
          begin
            # Get list of generated files from last generation
            if File.exist?(File.join(last_generated_dir, 'files.txt'))
              generated_files = File.readlines(File.join(last_generated_dir, 'files.txt')).map(&:strip)
              
              generated_files.each do |file|
                next unless File.exist?(file)
                
                # Check if file has uncommitted changes
                diff_output = `git diff --name-only #{file} 2>/dev/null`.strip
                staged_output = `git diff --cached --name-only #{file} 2>/dev/null`.strip
                
                if !diff_output.empty? || !staged_output.empty?
                  uncommitted_generated_files << file
                end
              end
            end
            
            if uncommitted_generated_files.empty?
              puts "✅ No undocumented diffs in generated files"
              true
            else
              puts "❌ Generated files have undocumented changes:"
              uncommitted_generated_files.each { |file| puts "  - #{file}" }
              puts "   Please commit or document these changes"
              false
            end
          rescue => e
            puts "⚠️  Could not check git diffs: #{e.message}"
            true # Don't fail for git issues
          end
        else
          puts "✅ Not a git repository - skipping diff check"
          true
        end
      end

      def verify_prompt_logs_consistency
        puts "\nVerifying prompt logs consistency:"
        
        prompts_log = '.railsplan/prompts.log'
        unless File.exist?(prompts_log)
          puts "✅ No prompt logs to verify"
          return true
        end
        
        begin
          # Check if prompt log is valid and recent
          log_content = File.read(prompts_log)
          log_lines = log_content.split("\n").reject(&:empty?)
          
          if log_lines.empty?
            puts "✅ Prompt log is empty"
            return true
          end
          
          # Check that each log entry has proper structure
          invalid_entries = 0
          log_lines.each_with_index do |line, index|
            begin
              entry = JSON.parse(line)
              unless entry.key?('timestamp') && entry.key?('prompt') && entry.key?('response')
                invalid_entries += 1
              end
            rescue JSON::ParserError
              invalid_entries += 1
            end
          end
          
          if invalid_entries == 0
            puts "✅ Prompt logs are valid (#{log_lines.length} entries)"
            true
          else
            puts "❌ #{invalid_entries} invalid prompt log entries found"
            false
          end
        rescue => e
          puts "❌ Error reading prompt logs: #{e.message}"
          false
        end
      end

      def verify_test_coverage_for_generated_code
        puts "\nVerifying test coverage for generated code:"
        
        last_generated_dir = '.railsplan/last_generated'
        unless Dir.exist?(last_generated_dir)
          puts "✅ No generated code to verify coverage for"
          return true
        end
        
        files_list = File.join(last_generated_dir, 'files.txt')
        unless File.exist?(files_list)
          puts "✅ No generated files list found"
          return true
        end
        
        generated_files = File.readlines(files_list).map(&:strip)
        missing_tests = []
        
        generated_files.each do |file|
          next unless file.end_with?('.rb')
          next if file.include?('/test/') || file.include?('/spec/')
          next unless file.include?('/models/') || file.include?('/controllers/')
          
          # Check if corresponding test file exists
          test_file = infer_test_file_path(file)
          unless File.exist?(test_file)
            missing_tests << file
          end
        end
        
        if missing_tests.empty?
          puts "✅ All generated code has corresponding tests"
          true
        else
          puts "❌ Generated files missing tests:"
          missing_tests.each { |file| puts "  - #{file}" }
          false
        end
      end

      def verify_module_configurations
        puts "\nVerifying module configurations:"
        
        registry = load_registry
        installed_modules = registry['installed'] || {}
        
        if installed_modules.empty?
          puts "✅ No modules to verify"
          return true
        end
        
        config_errors = []
        
        installed_modules.each do |module_name, info|
          # Check if module configuration is valid
          config_file = "config/initializers/#{module_name}.rb"
          if File.exist?(config_file)
            begin
              # Basic syntax check
              content = File.read(config_file)
              # This is a simple check - could be enhanced with actual Ruby parsing
              if content.strip.empty?
                config_errors << "#{module_name}: configuration file is empty"
              end
            rescue => e
              config_errors << "#{module_name}: #{e.message}"
            end
          else
            log_verbose("No configuration file for #{module_name} (optional)")
          end
        end
        
        if config_errors.empty?
          puts "✅ All module configurations are valid"
          true
        else
          puts "❌ Module configuration errors:"
          config_errors.each { |error| puts "  - #{error}" }
          false
        end
      end

      def verify_no_stale_artifacts
        puts "\nVerifying no stale artifacts:"
        
        stale_patterns = [
          '.railsplan/temp_*',
          '.railsplan/*.tmp',
          '.railsplan/cache/*',
          'tmp/railsplan_*'
        ]
        
        stale_files = []
        stale_patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            # Check if file is older than 1 day
            if File.mtime(file) < Time.now - (24 * 60 * 60)
              stale_files << file
            end
          end
        end
        
        if stale_files.empty?
          puts "✅ No stale artifacts found"
          true
        else
          puts "⚠️  Stale artifacts found (consider cleanup):"
          stale_files.each { |file| puts "  - #{file}" }
          true # Warning, not error
        end
      end

      def verify_environment_consistency
        puts "\nVerifying environment consistency:"
        
        env_files = ['.env.example', '.env']
        consistency_issues = []
        
        if File.exist?('.env.example') && File.exist?('.env')
          example_vars = extract_env_vars('.env.example')
          current_vars = extract_env_vars('.env')
          
          # Check for missing variables in .env
          missing_in_env = example_vars.keys - current_vars.keys
          unless missing_in_env.empty?
            consistency_issues << "Variables in .env.example but not in .env: #{missing_in_env.join(', ')}"
          end
          
          # Check for extra variables in .env (might be okay, just inform)
          extra_in_env = current_vars.keys - example_vars.keys
          if extra_in_env.any? && verbose
            puts "ℹ️  Extra variables in .env: #{extra_in_env.join(', ')}"
          end
        end
        
        if consistency_issues.empty?
          puts "✅ Environment configuration is consistent"
          true
        else
          puts "❌ Environment consistency issues:"
          consistency_issues.each { |issue| puts "  - #{issue}" }
          false
        end
      end

      def calculate_app_state_hash
        # Calculate a hash of key app files to detect changes
        files_to_hash = [
          'db/schema.rb',
          'config/routes.rb',
          Dir.glob('app/models/**/*.rb'),
          Dir.glob('app/controllers/**/*.rb')
        ].flatten.select { |f| File.exist?(f) }
        
        combined_content = files_to_hash.sort.map { |f| File.read(f) }.join
        Digest::SHA256.hexdigest(combined_content)
      end

      def infer_test_file_path(file)
        # Convert app file path to test file path
        if file.include?('/app/')
          test_file = file.sub('/app/', '/test/').sub('.rb', '_test.rb')
        else
          test_file = file.sub('.rb', '_test.rb')
        end
        
        # Also check for spec files
        spec_file = file.sub('/app/', '/spec/').sub('.rb', '_spec.rb')
        
        # Return the first one that might exist (prioritize test/ over spec/)
        File.exist?(test_file) ? test_file : spec_file
      end

      def extract_env_vars(file)
        vars = {}
        File.readlines(file).each do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')
          
          if line.include?('=')
            key, value = line.split('=', 2)
            vars[key.strip] = value&.strip
          end
        end
        vars
      end

      def generate_verification_report(results, failed_verifications)
        # Ensure .railsplan directory exists
        FileUtils.mkdir_p('.railsplan')
        
        report = {
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
          total_verifications: results.length,
          failed_verifications: failed_verifications,
          passed_verifications: results.length - failed_verifications,
          status: failed_verifications > 0 ? 'failed' : 'passed',
          ruby_version: RUBY_VERSION,
          railsplan_version: defined?(RailsPlan::VERSION) ? RailsPlan::VERSION : 'unknown'
        }
        
        report_file = '.railsplan/verify_report.json'
        File.write(report_file, JSON.pretty_generate(report))
        puts "📊 Verification report generated: #{report_file}"
      end
    end
  end
end