# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/context_manager"
require "railsplan/ai"

module RailsPlan
  module Commands
    # Command for AI-powered code generation
    class GenerateCommand < BaseCommand
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
      end
      
      def execute(instruction, options = {})
        puts "🤖 Generating Rails code with AI..."
        puts "📝 Instruction: #{instruction}"
        puts ""
        
        unless rails_app?
          puts "❌ Not in a Rails application directory"
          return false
        end
        
        # Determine provider
        provider = determine_provider(options)
        format = determine_format(options)
        
        puts "🔧 Using #{provider} (#{format} format)"
        
        # Check if context exists and is up to date
        ensure_context_available(options)
        
        begin
          # Generate code with AI
          context = @context_manager.load_context || {}
          
          puts "⏳ Generating code..."
          result = RailsPlan::AI.call(
            provider: provider,
            prompt: build_generation_prompt(instruction, context),
            context: context,
            format: format,
            creative: options[:creative],
            max_tokens: options[:max_tokens],
            allow_fallback: true
          )
          
          puts "✅ Code generated successfully!"
          puts ""
          puts "📋 #{result[:metadata][:model] || 'AI'} response:"
          puts ""
          
          # Parse the response based on format
          files = parse_generation_response(result[:output], format)
          
          if files.empty?
            puts "⚠️  No files were generated"
            return false
          end
          
          # Show preview of generated files
          show_file_preview(files)
          
          # Ask for confirmation
          if options[:force] || confirm_generation(files, result)
            write_files(files)
            show_completion_info(result)
            
            # Update context after successful generation
            @context_manager.extract_context
            
            true
          else
            puts "❌ Generation cancelled by user"
            false
          end
          
        rescue RailsPlan::Error => e
          puts "❌ AI generation failed: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        rescue StandardError => e
          puts "❌ Unexpected error during generation: #{e.message}"
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def determine_provider(options)
        # Check CLI option first
        if options[:provider]
          return options[:provider].to_sym
        end
        
        # Fall back to default from configuration
        RailsPlan::AI.default_provider
      end
      
      def determine_format(options)
        format = options[:format] || "ruby"
        format.to_sym
      end
      
      def build_generation_prompt(instruction, context)
        prompt = <<~PROMPT
          You are an expert Rails developer. Generate Rails application code based on this instruction:
          
          #{instruction}
          
          Generate complete, working Rails files including:
          - Models with appropriate validations and associations
          - Database migrations
          - Controllers with standard REST actions
          - Routes
          - Basic views (if applicable)
          - Tests (if applicable)
          
          Follow Rails conventions and best practices. Use the application context to ensure consistency with existing code patterns.
        PROMPT
      end
      
      def parse_generation_response(output, format)
        case format
        when :json
          begin
            parsed = JSON.parse(output)
            return parsed["files"] || {}
          rescue JSON::ParserError
            # Fall through to code block extraction
          end
        when :ruby
          # For Ruby format, try to extract multiple files
          files = extract_code_blocks_from_ruby(output)
          return files unless files.empty?
        end
        
        # Fallback: try to extract code blocks from markdown
        extract_code_blocks(output)
      end
      
      def extract_code_blocks_from_ruby(output)
        files = {}
        
        # Look for file headers and code
        output.scan(/^# File: ([^\n]+)\s*\n(.*?)(?=^# File: |$)/m) do |filename, content|
          files[filename.strip] = content.strip
        end
        
        # If no file headers found, treat as single file
        if files.empty? && !output.strip.empty?
          files["generated_code.rb"] = output.strip
        end
        
        files
      end
      
      def extract_code_blocks(text)
        files = {}
        
        # Extract code blocks with file names
        text.scan(/```(?:ruby|erb|yaml|rb)?\s*\n# ([^\n]+)\n(.*?)\n```/m) do |filename, content|
          files[filename.strip] = content.strip
        end
        
        # If no named blocks, look for generic code blocks
        if files.empty?
          text.scan(/```(?:ruby|erb|yaml|rb)?\s*\n(.*?)\n```/m) do |content|
            files["generated_code.rb"] = content.first.strip
            break # Only take the first one
          end
        end
        
        files
      end
      
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
      
      def show_configuration_help
        puts "❌ AI provider not configured"
        puts ""
        puts "To configure AI providers, create ~/.railsplan/ai.yml:"
        puts ""
        puts "  mkdir -p ~/.railsplan"
        puts "  cat > ~/.railsplan/ai.yml << EOF"
        puts "  provider: openai"
        puts "  model: gpt-4o"
        puts "  openai_api_key: <%= ENV['OPENAI_API_KEY'] %>"
        puts "  claude_api_key: <%= ENV['ANTHROPIC_API_KEY'] %>"
        puts "  gemini_api_key: <%= ENV['GOOGLE_API_KEY'] %>"
        puts "  EOF"
        puts ""
        puts "Or set environment variables:"
        puts "  export OPENAI_API_KEY=your_key_here"
        puts "  export RAILSPLAN_AI_PROVIDER=openai"
        puts ""
        puts "Run 'railsplan chat' to test your configuration."
      end
      
      def show_file_preview(files)
        puts "📁 Files to be generated:"
        files.each do |file_path, content|
          puts "  #{file_path} (#{content.lines.count} lines)"
        end
        puts ""
      end
      
      def confirm_generation(files, result)
        require "tty-prompt"
        prompt = TTY::Prompt.new
        
        choices = [
          { name: "✅ Accept and write files", value: :accept },
          { name: "👀 Preview individual files", value: :preview },
          { name: "✏️  Modify instruction", value: :modify },
          { name: "❌ Cancel", value: :cancel }
        ]
        
        action = prompt.select("What would you like to do?", choices)
        
        case action
        when :accept
          true
        when :preview
          preview_files(files)
          confirm_generation(files, result)
        when :modify
          puts "💡 Tip: You can run the generate command again with a modified instruction"
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
      
      def show_completion_info(result)
        puts ""
        puts "📊 Generation completed:"
        if result[:metadata]
          puts "  Provider: #{result[:metadata][:provider]}"
          puts "  Model: #{result[:metadata][:model]}"
          puts "  Tokens: #{result[:metadata][:tokens_used] || 'N/A'}"
          puts "  Cost: $#{result[:metadata][:cost_estimate] || 0.0}"
        end
        
        puts ""
        puts "🚀 Next steps:"
        puts "  1. Review the generated files"
        puts "  2. Run tests: rails test"
        puts "  3. Run migrations if any were generated: rails db:migrate"
      end
      
      def write_files(files)
        puts "📝 Writing files..."
        
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
        
        puts "✅ All files written successfully!"
      end
    end
  end
end