# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/context_manager"
require "railsplan/ai_config"
require "railsplan/ai_generator"
require "railsplan"

module RailsPlan
  module Commands
    # Command for AI-powered test generation
    class TestGenerateCommand < BaseCommand
      TEST_TYPES = %w[system request model job controller integration unit].freeze
      
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
      end
      
      def execute(instruction, options = {})
        puts "🧪 Generating Rails tests with AI..."
        puts "📝 Test instruction: #{instruction}"
        puts ""
        
        unless rails_app?
          puts "❌ Not in a Rails application directory"
          return false
        end
        
        # Setup AI configuration
        profile = options[:profile] || "default"
        ai_config = AIConfig.new(profile: profile)
        
        unless ai_config.configured?
          show_configuration_help
          return false
        end
        
        puts "🔧 Using #{ai_config.provider} (#{ai_config.model})"
        
        # Check if context exists and is up to date
        ensure_context_available(options)
        
        begin
          # Determine test type
          test_type = determine_test_type(instruction, options)
          puts "🎯 Detected test type: #{test_type}"
          puts ""
          
          # Generate test with AI
          ai_generator = AIGenerator.new(ai_config, @context_manager)
          
          puts "⏳ Generating #{test_type} test..."
          result = generate_test_with_ai(ai_generator, instruction, test_type, options)
          
          puts "✅ Test generated successfully!"
          puts ""
          puts "📋 #{result[:description]}"
          puts ""
          
          if result[:files].empty?
            puts "⚠️  No test files were generated"
            return false
          end
          
          # Show preview of generated files
          show_file_preview(result[:files])
          
          # Handle dry run
          if options[:dry_run]
            puts "🔍 Dry run mode - no files written"
            return true
          end
          
          # Ask for confirmation unless forced
          if options[:force] || confirm_generation(result)
            write_files(result[:files])
            show_next_steps(result[:instructions])
            
            # Run doctor command to validate tests if requested
            if options[:validate]
              validate_generated_tests(result[:files])
            end
            
            # Update context after successful generation
            @context_manager.extract_context
            
            true
          else
            puts "❌ Test generation cancelled by user"
            false
          end
          
        rescue RailsPlan::Error => e
          puts "❌ AI test generation failed: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        rescue StandardError => e
          puts "❌ Unexpected error during test generation: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def rails_app?
        File.exist?("config/application.rb") || File.exist?("Gemfile")
      end
      
      def ensure_context_available(options)
        if !@context_manager.load_context || @context_manager.context_stale?
          puts "🔍 Extracting application context..."
          @context_manager.extract_context
          puts "✅ Context updated"
          puts ""
        end
      end
      
      def determine_test_type(instruction, options)
        # If type is explicitly specified, use it
        if options[:type] && TEST_TYPES.include?(options[:type])
          return options[:type]
        end
        
        # Auto-detect based on instruction content
        instruction_lower = instruction.downcase
        
        # System/feature tests - user interactions
        if instruction_lower.match?(/sign[s]?\s+up|sign[s]?\s+in|log[s]?\s+in|visit|click|fill|submit|user\s+.*(flow|journey|interaction)|browser/)
          return "system"
        end
        
        # API/Request tests - HTTP endpoints
        if instruction_lower.match?(/api|endpoint|request|response|post\s+|get\s+|put\s+|patch\s+|delete\s+|http|json|status/)
          return "request"
        end
        
        # Model tests - validations, associations, methods
        if instruction_lower.match?(/model|validation|association|scope|method.*model|database|\.save|\.create|\.find/)
          return "model"
        end
        
        # Job tests - background processing
        if instruction_lower.match?(/job|perform|queue|background|sidekiq|delayed|async/)
          return "job"
        end
        
        # Controller tests - controller actions
        if instruction_lower.match?(/controller|action|params|redirect|render|before_action/)
          return "controller"
        end
        
        # Default to system test for user stories
        "system"
      end
      
      def generate_test_with_ai(ai_generator, instruction, test_type, options)
        context = @context_manager.load_context
        enhanced_instruction = build_test_instruction(instruction, test_type, context)
        
        # Use a specialized test generation prompt
        test_options = options.merge(test_type: test_type)
        ai_generator.generate(enhanced_instruction, test_options)
      end
      
      def build_test_instruction(instruction, test_type, context)
        test_framework = detect_test_framework(context)
        
        enhanced_instruction = <<~INSTRUCTION
          Generate a #{test_type} test using #{test_framework} for the following requirement:
          
          #{instruction}
          
          Requirements for #{test_type} test:
          #{test_requirements_for_type(test_type, test_framework)}
          
          Follow these conventions:
          - Use descriptive test names that explain the behavior being tested
          - Include proper setup and teardown if needed
          - Add comments explaining complex test logic
          - Use realistic test data and scenarios
          - Follow Rails testing best practices
          - Ensure tests are isolated and can run independently
        INSTRUCTION
        
        enhanced_instruction
      end
      
      def detect_test_framework(context)
        # Check if RSpec is in use
        if File.exist?("spec/spec_helper.rb") || File.exist?("spec/rails_helper.rb")
          return "RSpec"
        end
        
        # Check for Minitest
        if File.exist?("test/test_helper.rb") || (context && context["modules"]&.include?("minitest"))
          return "Minitest"
        end
        
        # Default to Rails' built-in Minitest
        "Minitest"
      end
      
      def test_requirements_for_type(test_type, framework)
        case test_type
        when "system"
          if framework == "RSpec"
            <<~REQUIREMENTS
              - Place in spec/system/ directory
              - Use Capybara DSL (visit, fill_in, click_button, etc.)
              - Include realistic user interactions and assertions
              - Test end-to-end user workflows
              - Use `feature` and `scenario` blocks for RSpec
              - Include `js: true` for JavaScript interactions if needed
            REQUIREMENTS
          else
            <<~REQUIREMENTS
              - Place in test/system/ directory  
              - Use Capybara DSL (visit, fill_in, click_button, etc.)
              - Inherit from ApplicationSystemTestCase
              - Include realistic user interactions and assertions
              - Test end-to-end user workflows
            REQUIREMENTS
          end
        when "request"
          if framework == "RSpec"
            <<~REQUIREMENTS
              - Place in spec/requests/ directory
              - Test HTTP endpoints directly
              - Use get, post, put, patch, delete methods
              - Assert response status, headers, and body content
              - Test authentication and authorization
              - Include JSON response parsing if API endpoint
            REQUIREMENTS
          else
            <<~REQUIREMENTS
              - Place in test/integration/ directory
              - Inherit from ActionDispatch::IntegrationTest
              - Test HTTP endpoints directly
              - Use get, post, put, patch, delete methods
              - Assert response status, headers, and body content
              - Test authentication and authorization
            REQUIREMENTS
          end
        when "model"
          if framework == "RSpec"
            <<~REQUIREMENTS
              - Place in spec/models/ directory
              - Test validations, associations, and scopes
              - Test instance and class methods
              - Use RSpec matchers for validations
              - Include edge cases and error conditions
              - Test database constraints and callbacks
            REQUIREMENTS
          else
            <<~REQUIREMENTS
              - Place in test/models/ directory
              - Inherit from ActiveSupport::TestCase
              - Test validations, associations, and scopes
              - Test instance and class methods
              - Use Rails assertions (assert_valid, assert_not_valid, etc.)
              - Include edge cases and error conditions
            REQUIREMENTS
          end
        when "job"
          if framework == "RSpec"
            <<~REQUIREMENTS
              - Place in spec/jobs/ directory
              - Test job execution and side effects
              - Mock external services and APIs
              - Test job scheduling and queuing
              - Verify job arguments and behavior
              - Test job failures and retry logic
            REQUIREMENTS
          else
            <<~REQUIREMENTS
              - Place in test/jobs/ directory
              - Inherit from ActiveJob::TestCase
              - Test job execution and side effects
              - Use assert_enqueued_jobs and perform_enqueued_jobs
              - Mock external services and APIs
              - Test job arguments and behavior
            REQUIREMENTS
          end
        when "controller"
          if framework == "RSpec"
            <<~REQUIREMENTS
              - Place in spec/controllers/ directory
              - Test controller actions in isolation
              - Test parameter handling and filtering
              - Test response rendering and redirects
              - Mock models and services
              - Test authentication and authorization
            REQUIREMENTS
          else
            <<~REQUIREMENTS
              - Place in test/controllers/ directory
              - Inherit from ActionController::TestCase
              - Test controller actions in isolation
              - Use get, post, put, patch, delete with params
              - Test response rendering and redirects
              - Test authentication and authorization
            REQUIREMENTS
          end
        else
          "- Follow standard #{framework} testing practices"
        end
      end
      
      def show_configuration_help
        puts "❌ AI provider not configured"
        puts ""
        puts "To configure AI providers, create #{AIConfig::DEFAULT_CONFIG_PATH}:"
        puts ""
        puts "  mkdir -p ~/.railsplan"
        puts "  cat > ~/.railsplan/ai.yml << EOF"
        puts "  default:"
        puts "    provider: openai"
        puts "    model: gpt-4o"
        puts "    api_key: <%= ENV['OPENAI_API_KEY'] %>"
        puts "  profiles:"
        puts "    test:"
        puts "      provider: anthropic"
        puts "      model: claude-3-sonnet"
        puts "      api_key: <%= ENV['CLAUDE_KEY'] %>"
        puts "  EOF"
        puts ""
        puts "Or set environment variables:"
        puts "  export OPENAI_API_KEY=your_key_here"
        puts "  export RAILSPLAN_AI_PROVIDER=openai"
      end
      
      def show_file_preview(files)
        puts "📁 Test files to be generated:"
        files.each do |file_path, content|
          puts "  #{file_path} (#{content.lines.count} lines)"
        end
        puts ""
      end
      
      def confirm_generation(result)
        require "tty-prompt"
        prompt = TTY::Prompt.new
        
        choices = [
          { name: "✅ Accept and write test files", value: :accept },
          { name: "👀 Preview test files", value: :preview },
          { name: "✏️  Modify test instruction", value: :modify },
          { name: "❌ Cancel", value: :cancel }
        ]
        
        action = prompt.select("What would you like to do?", choices)
        
        case action
        when :accept
          true
        when :preview
          preview_files(result[:files])
          confirm_generation(result)
        when :modify
          puts "💡 Tip: You can run the generate test command again with a modified instruction"
          false
        when :cancel
          false
        end
      end
      
      def preview_files(files)
        require "tty-prompt"
        prompt = TTY::Prompt.new
        
        files.each do |file_path, content|
          puts ""
          puts "📄 #{file_path}:"
          puts "─" * 50
          puts content
          puts "─" * 50
          
          unless prompt.yes?("Continue to next file?")
            break
          end
        end
      end
      
      def write_files(files)
        puts "📝 Writing test files..."
        
        files.each do |file_path, content|
          full_path = File.expand_path(file_path)
          
          # Ensure directory exists
          FileUtils.mkdir_p(File.dirname(full_path))
          
          # Check if file exists
          if File.exist?(full_path)
            puts "  ⚠️  Overwriting #{file_path}"
          else
            puts "  ✅ Creating #{file_path}"
          end
          
          File.write(full_path, content)
        end
        
        puts "✅ All test files written successfully!"
      end
      
      def show_next_steps(instructions)
        return if instructions.empty?
        
        puts ""
        puts "🚀 Next steps:"
        instructions.each_with_index do |instruction, index|
          puts "  #{index + 1}. #{instruction}"
        end
      end
      
      def validate_generated_tests(files)
        puts ""
        puts "🔍 Validating generated tests..."
        
        files.each do |file_path, _content|
          if File.exist?(file_path)
            # Basic syntax validation by trying to load the file
            begin
              # For Ruby files, check syntax
              if file_path.end_with?('.rb')
                system("ruby -c #{file_path}")
                puts "  ✅ #{file_path} - syntax valid"
              end
            rescue => e
              puts "  ❌ #{file_path} - syntax error: #{e.message}"
            end
          else
            puts "  ❌ #{file_path} - file not found"
          end
        end
      end
    end
  end
end