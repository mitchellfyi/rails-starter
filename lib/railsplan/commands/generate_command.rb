# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/context_manager"
require "railsplan/ai_config"
require "railsplan/ai_generator"
require "railsplan"

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
          # Generate code with AI
          ai_generator = AIGenerator.new(ai_config, @context_manager)
          
          puts "⏳ Generating code..."
          result = ai_generator.generate(instruction, options)
          
          puts "✅ Code generated successfully!"
          puts ""
          puts "📋 #{result[:description]}"
          puts ""
          
          if result[:files].empty?
            puts "⚠️  No files were generated"
            return false
          end
          
          # Show preview of generated files
          show_file_preview(result[:files])
          
          # Ask for confirmation
          if options[:force] || confirm_generation(result)
            write_files(result[:files])
            show_next_steps(result[:instructions])
            
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
        puts ""
        puts "Run 'railsplan generate --help' for more configuration options."
      end
      
      def show_file_preview(files)
        puts "📁 Files to be generated:"
        files.each do |file_path, content|
          puts "  #{file_path} (#{content.lines.count} lines)"
        end
        puts ""
      end
      
      def confirm_generation(result)
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
          preview_files(result[:files])
          confirm_generation(result)
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
      
      def show_next_steps(instructions)
        return if instructions.empty?
        
        puts ""
        puts "🚀 Next steps:"
        instructions.each_with_index do |instruction, index|
          puts "  #{index + 1}. #{instruction}"
        end
      end
    end
  end
end