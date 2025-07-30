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