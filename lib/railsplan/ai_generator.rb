# frozen_string_literal: true

require "json"

module RailsPlan
  # Handles AI-powered code generation
  class AIGenerator
    attr_reader :ai_config, :context_manager
    
    def initialize(ai_config, context_manager)
      @ai_config = ai_config
      @context_manager = context_manager
    end
    
    def generate(instruction, options = {})
      raise RailsPlan::Error, "AI provider not configured" unless @ai_config.configured?
      
      # Ensure context is up to date
      if @context_manager.context_stale?
        RailsPlan.logger.info("Context is stale, updating...")
        @context_manager.extract_context
      end
      
      context = @context_manager.load_context
      prompt = build_prompt(instruction, context, options)
      
      RailsPlan.logger.debug("Sending prompt to #{@ai_config.provider}")
      
      response = send_to_ai(prompt, options)
      
      # Log the interaction
      @context_manager.log_prompt(prompt, response, {
        provider: @ai_config.provider,
        model: @ai_config.model,
        instruction: instruction,
        options: options
      })
      
      parsed_response = parse_ai_response(response)
      
      # Save the generated files for recovery
      @context_manager.save_last_generated(parsed_response[:files]) if parsed_response[:files]
      
      parsed_response
    end
    
    private
    
    def build_prompt(instruction, context, options)
      if options[:test_type]
        build_test_prompt(instruction, context, options)
      else
        build_general_prompt(instruction, context, options)
      end
    end
    
    def build_general_prompt(instruction, context, options)
      prompt = <<~PROMPT
        You are an expert Rails developer assistant. Generate Rails code based on the user's instruction.
        
        ## User Instruction
        #{instruction}
        
        ## Current Application Context
        #{format_context(context)}
        
        ## Requirements
        1. Follow Rails conventions and best practices
        2. Use appropriate naming that matches existing codebase patterns
        3. Generate complete, working code files
        4. Include proper validations, associations, and tests when applicable
        5. Follow the existing architecture patterns shown in the context
        
        ## Response Format
        Respond with a JSON object containing:
        ```json
        {
          "description": "Brief description of what was generated",
          "files": {
            "path/to/file.rb": "file content here",
            "another/file.rb": "another file content"
          },
          "instructions": [
            "Run rails db:migrate",
            "Any other setup instructions"
          ]
        }
        ```
        
        ## Code Style Guidelines
        - Use 2-space indentation
        - Follow Ruby style guidelines
        - Include appropriate comments for complex logic
        - Use modern Rails idioms and patterns
        - Ensure all generated code is syntactically correct
        
        Generate the appropriate Rails files (models, migrations, controllers, views, tests) based on the instruction.
      PROMPT
    end
    
    def build_test_prompt(instruction, context, options)
      test_type = options[:test_type]
      test_framework = detect_test_framework(context)
      
      prompt = <<~PROMPT
        You are an expert Rails test developer. Generate comprehensive #{test_type} tests using #{test_framework}.
        
        ## Test Instruction
        #{instruction}
        
        ## Current Application Context
        #{format_context(context)}
        
        ## Test Requirements for #{test_type.upcase} tests
        #{test_requirements_for_type(test_type, test_framework)}
        
        ## Response Format
        Respond with a JSON object containing:
        ```json
        {
          "description": "Brief description of the test generated",
          "files": {
            "#{test_file_path_for_type(test_type, test_framework)}": "complete test file content"
          },
          "instructions": [
            "Run the test with: #{test_run_command(test_framework)}",
            "Any additional setup instructions"
          ]
        }
        ```
        
        ## Test Code Guidelines
        - Use 2-space indentation
        - Write descriptive test names that explain the behavior
        - Include proper setup and teardown
        - Use realistic test data and scenarios
        - Add helpful comments explaining test logic
        - Ensure tests are isolated and can run independently
        - Follow #{test_framework} best practices
        - Include edge cases and error scenarios
        - Use appropriate assertions and matchers
        
        Generate ONLY the test file. Make it comprehensive and production-ready.
      PROMPT
    end
    
    def detect_test_framework(context)
      # Check if RSpec is mentioned in context or files exist
      if context && (context["modules"]&.include?("rspec") || 
                     context.dig("files", "spec/spec_helper.rb") ||
                     context.dig("files", "spec/rails_helper.rb"))
        return "RSpec"
      end
      
      # Check file system as fallback
      if File.exist?("spec/spec_helper.rb") || File.exist?("spec/rails_helper.rb")
        return "RSpec"
      end
      
      # Default to Minitest (Rails default)
      "Minitest"
    end
    
    def test_requirements_for_type(test_type, framework)
      case test_type
      when "system"
        if framework == "RSpec"
          <<~REQUIREMENTS
            - Create a feature spec in spec/system/ directory
            - Use RSpec feature/scenario syntax
            - Use Capybara DSL: visit, fill_in, click_button, click_link, etc.
            - Include realistic user interactions and page assertions
            - Test complete user workflows end-to-end
            - Use expect(page).to have_content(), have_css(), etc.
            - Add js: true for JavaScript interactions if needed
            - Set up test data using factories or fixtures
          REQUIREMENTS
        else
          <<~REQUIREMENTS
            - Create a system test in test/system/ directory
            - Inherit from ApplicationSystemTestCase
            - Use Capybara DSL: visit, fill_in, click_button, click_link, etc.
            - Include realistic user interactions and page assertions  
            - Test complete user workflows end-to-end
            - Use assert_text, assert_selector, etc.
            - Set up test data in setup method
          REQUIREMENTS
        end
      when "request"
        if framework == "RSpec"
          <<~REQUIREMENTS
            - Create a request spec in spec/requests/ directory
            - Test HTTP endpoints directly using get, post, put, patch, delete
            - Assert response status: expect(response).to have_http_status(:ok)
            - Test response body and headers
            - Include authentication and authorization tests
            - Test both successful and error scenarios
            - Parse and verify JSON responses for API endpoints
          REQUIREMENTS
        else
          <<~REQUIREMENTS
            - Create an integration test in test/integration/ directory
            - Inherit from ActionDispatch::IntegrationTest
            - Test HTTP endpoints using get, post, put, patch, delete
            - Assert response status: assert_response :success
            - Test response body and headers
            - Include authentication and authorization tests
            - Test both successful and error scenarios
          REQUIREMENTS
        end
      when "model"
        if framework == "RSpec"
          <<~REQUIREMENTS
            - Create a model spec in spec/models/ directory
            - Test validations using shoulda-matchers or custom expectations
            - Test associations: belong_to, has_many, etc.
            - Test scopes and class methods
            - Test instance methods and callbacks
            - Include edge cases and validation failures
            - Test database constraints
          REQUIREMENTS
        else
          <<~REQUIREMENTS
            - Create a model test in test/models/ directory
            - Inherit from ActiveSupport::TestCase
            - Test validations using assert_valid, assert_not_valid
            - Test associations and their behavior
            - Test scopes and class methods
            - Test instance methods and callbacks
            - Include edge cases and validation failures
          REQUIREMENTS
        end
      when "controller"
        if framework == "RSpec"
          <<~REQUIREMENTS
            - Create a controller spec in spec/controllers/ directory
            - Test each action individually
            - Mock dependencies and external services
            - Test parameter handling and strong parameters
            - Test response rendering, redirects, and status codes
            - Test authentication and authorization
            - Verify instance variables and their assignment
          REQUIREMENTS
        else
          <<~REQUIREMENTS
            - Create a controller test in test/controllers/ directory
            - Inherit from ActionController::TestCase
            - Test each action with appropriate HTTP verbs
            - Test parameter handling and response types
            - Test authentication and authorization
            - Use assert_response, assert_redirected_to, etc.
            - Verify instance variables with assigns()
          REQUIREMENTS
        end
      when "job"
        if framework == "RSpec"
          <<~REQUIREMENTS
            - Create a job spec in spec/jobs/ directory
            - Test job execution and side effects
            - Mock external APIs and services
            - Test job arguments and serialization
            - Test error handling and retry logic
            - Verify job scheduling and queue assignment
          REQUIREMENTS
        else
          <<~REQUIREMENTS
            - Create a job test in test/jobs/ directory
            - Inherit from ActiveJob::TestCase
            - Use assert_enqueued_jobs and perform_enqueued_jobs
            - Test job execution and side effects
            - Mock external APIs and services
            - Test job arguments and error handling
          REQUIREMENTS
        end
      else
        "Follow standard #{framework} testing practices for #{test_type} tests"
      end
    end
    
    def test_file_path_for_type(test_type, framework)
      base_dir = framework == "RSpec" ? "spec" : "test"
      
      case test_type
      when "system"
        "#{base_dir}/system/example_#{test_type}_test.rb"
      when "request"
        request_dir = framework == "RSpec" ? "requests" : "integration"
        "#{base_dir}/#{request_dir}/example_#{test_type}_test.rb"
      when "model"
        "#{base_dir}/models/example_model_test.rb"
      when "controller"
        "#{base_dir}/controllers/example_controller_test.rb"
      when "job"
        "#{base_dir}/jobs/example_job_test.rb"
      else
        "#{base_dir}/#{test_type}/example_test.rb"
      end
    end
    
    def test_run_command(framework)
      if framework == "RSpec"
        "bundle exec rspec"
      else
        "rails test"
      end
    end
    
    def format_context(context)
      return "No context available" unless context
      
      formatted = []
      
      if context["app_name"]
        formatted << "**Application:** #{context["app_name"]}"
      end
      
      if context["models"] && !context["models"].empty?
        formatted << "\n**Existing Models:**"
        context["models"].each do |model|
          formatted << "- #{model["class_name"]}"
          if model["associations"] && !model["associations"].empty?
            model["associations"].each do |assoc|
              formatted << "  - #{assoc["type"]} :#{assoc["name"]}"
            end
          end
        end
      end
      
      if context["schema"] && !context["schema"].empty?
        formatted << "\n**Database Tables:**"
        context["schema"].each do |table_name, table_info|
          formatted << "- #{table_name}"
          if table_info["columns"]
            table_info["columns"].each do |col_name, col_info|
              formatted << "  - #{col_name}: #{col_info["type"]}"
            end
          end
        end
      end
      
      if context["routes"] && !context["routes"].empty?
        formatted << "\n**Existing Routes:**"
        context["routes"].take(10).each do |route|
          next unless route["controller"] && route["action"]
          formatted << "- #{route["verb"]} #{route["path"]} → #{route["controller"]}##{route["action"]}"
        end
        formatted << "  (showing first 10 routes)" if context["routes"].length > 10
      end
      
      if context["modules"] && !context["modules"].empty?
        formatted << "\n**Installed Modules:** #{context["modules"].join(", ")}"
      end
      
      formatted.join("\n")
    end
    
    def send_to_ai(prompt, options)
      client = @ai_config.client
      
      case @ai_config.provider
      when "openai"
        send_to_openai(client, prompt, options)
      when "anthropic"
        send_to_anthropic(client, prompt, options)
      else
        raise RailsPlan::Error, "Unsupported provider: #{@ai_config.provider}"
      end
    end
    
    def send_to_openai(client, prompt, options)
      temperature = options[:creative] ? 0.7 : 0.1
      
      response = client.chat(
        parameters: {
          model: @ai_config.model,
          messages: [
            { role: "user", content: prompt }
          ],
          temperature: temperature,
          max_tokens: options[:max_tokens] || 4000
        }
      )
      
      if response.dig("choices", 0, "message", "content")
        response.dig("choices", 0, "message", "content")
      else
        raise RailsPlan::Error, "Invalid response from OpenAI: #{response}"
      end
    rescue StandardError => e
      raise RailsPlan::Error, "OpenAI API error: #{e.message}"
    end
    
    def send_to_anthropic(client, prompt, options)
      temperature = options[:creative] ? 0.7 : 0.1
      
      response = client.messages(
        model: @ai_config.model,
        max_tokens: options[:max_tokens] || 4000,
        temperature: temperature,
        messages: [
          { role: "user", content: prompt }
        ]
      )
      
      if response.dig("content", 0, "text")
        response.dig("content", 0, "text")
      else
        raise RailsPlan::Error, "Invalid response from Anthropic: #{response}"
      end
    rescue StandardError => e
      raise RailsPlan::Error, "Anthropic API error: #{e.message}"
    end
    
    def parse_ai_response(response)
      # Try to find JSON in the response
      json_match = response.match(/```json\s*(\{.*?\})\s*```/m)
      json_content = json_match ? json_match[1] : response
      
      begin
        parsed = JSON.parse(json_content)
        
        # Validate required structure
        unless parsed.is_a?(Hash) && parsed["files"].is_a?(Hash)
          raise JSON::ParserError, "Invalid response structure"
        end
        
        {
          description: parsed["description"] || "Generated Rails code",
          files: parsed["files"] || {},
          instructions: parsed["instructions"] || []
        }
      rescue JSON::ParserError => e
        RailsPlan.logger.error("Failed to parse AI response: #{e.message}")
        RailsPlan.logger.debug("Raw response: #{response}")
        
        # Fallback: try to extract code blocks
        files = extract_code_blocks(response)
        
        {
          description: "Generated code (parsed from response)",
          files: files,
          instructions: ["Review generated code and make necessary adjustments"]
        }
      end
    end
    
    def extract_code_blocks(response)
      files = {}
      
      # Look for file headers and code blocks
      response.scan(/^(?:File: |# )([^\n]+\.rb)\s*\n```(?:ruby)?\s*\n(.*?)\n```/m) do |filename, content|
        # Clean up the filename
        clean_filename = filename.strip.gsub(/^[#\s]*/, "")
        files[clean_filename] = content.strip
      end
      
      # If no files found, create a single file with all code
      if files.empty?
        code_blocks = response.scan(/```(?:ruby)?\s*\n(.*?)\n```/m)
        if !code_blocks.empty?
          files["generated_code.rb"] = code_blocks.map(&:first).join("\n\n")
        end
      end
      
      files
    end
  end
end