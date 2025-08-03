# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/ai"
require "json"

module RailsPlan
  module Commands
    # Command for interactive AI chat and testing
    class ChatCommand < BaseCommand
      def execute(prompt, options = {})
        puts "🤖 AI Chat Mode - Testing multiple providers"
        puts ""
        
        if prompt
          # Single prompt mode
          execute_single_prompt(prompt, options)
        else
          # Interactive mode
          execute_interactive_mode(options)
        end
        
        true
      rescue RailsPlan::Error => e
        puts "❌ Chat failed: #{e.message}"
        log_verbose(e.backtrace.join("\n")) if verbose
        false
      rescue StandardError => e
        puts "❌ Unexpected error during chat: #{e.message}"
        log_verbose(e.backtrace.join("\n")) if verbose
        false
      end
      
      private
      
      def execute_single_prompt(prompt, options)
        provider = determine_provider(options)
        format = (options[:format] || :markdown).to_sym
        
        puts "🔧 Provider: #{provider}"
        puts "📋 Format: #{format}"
        puts "📝 Prompt: #{prompt}"
        puts ""
        puts "⏳ Processing..."
        
        begin
          result = RailsPlan::AI.call(
            provider: provider,
            prompt: prompt,
            format: format,
            creative: options[:creative],
            max_tokens: options[:max_tokens],
            allow_fallback: true
          )
          
          display_result(result, format)
          
        rescue RailsPlan::Error => e
          puts "❌ Error: #{e.message}"
          suggest_alternatives(provider)
        end
      end
      
      def execute_interactive_mode(options)
        puts "🎯 Interactive AI Chat"
        puts "Type 'exit' to quit, 'help' for commands, 'providers' to list available providers"
        puts ""
        
        require "tty-prompt"
        prompt_tool = TTY::Prompt.new
        
        current_provider = determine_provider(options)
        current_format = (options[:format] || :markdown).to_sym
        
        loop do
          puts "Current: #{current_provider} (#{current_format})"
          user_input = prompt_tool.ask("💬 You:", required: false)
          
          break if user_input.nil? || user_input.strip.downcase == "exit"
          
          case user_input.strip.downcase
          when "help"
            show_help
          when "providers"
            show_providers
          when /^provider\s+(\w+)$/
            new_provider = $1.to_sym
            if RailsPlan::AI.available_providers.include?(new_provider)
              current_provider = new_provider
              puts "✅ Switched to #{new_provider}"
            else
              puts "❌ Unknown provider: #{new_provider}"
              show_providers
            end
          when /^format\s+(\w+)$/
            new_format = $1.to_sym
            valid_formats = [:markdown, :ruby, :json, :html_partial]
            if valid_formats.include?(new_format)
              current_format = new_format
              puts "✅ Switched to #{new_format} format"
            else
              puts "❌ Unknown format: #{new_format}. Valid: #{valid_formats.join(', ')}"
            end
          when ""
            next
          else
            # Process as AI prompt
            puts "⏳ Processing..."
            
            begin
              result = RailsPlan::AI.call(
                provider: current_provider,
                prompt: user_input,
                format: current_format,
                creative: options[:creative],
                max_tokens: options[:max_tokens],
                allow_fallback: true
              )
              
              display_result(result, current_format)
              
            rescue RailsPlan::Error => e
              puts "❌ Error: #{e.message}"
              suggest_alternatives(current_provider)
            end
          end
          
          puts ""
        end
        
        puts "👋 Goodbye!"
      end
      
      def determine_provider(options)
        # Check CLI option first
        if options[:provider]
          return options[:provider].to_sym
        end
        
        # Check global CLI option
        if options[:global]&.[](:provider)
          return options[:global][:provider].to_sym
        end
        
        # Fall back to default
        RailsPlan::AI.default_provider
      end
      
      def display_result(result, format)
        puts "🎯 Response:"
        puts "─" * 50
        
        case format
        when :json
          begin
            # Pretty print JSON
            parsed = JSON.parse(result[:output])
            puts JSON.pretty_generate(parsed)
          rescue JSON::ParserError
            puts result[:output]
          end
        when :ruby
          puts result[:output]
        else
          puts result[:output]
        end
        
        puts "─" * 50
        
        # Show metadata if verbose
        if verbose && result[:metadata]
          puts ""
          puts "📊 Metadata:"
          puts "  Model: #{result[:metadata][:model]}"
          puts "  Tokens: #{result[:metadata][:tokens_used] || 'N/A'}"
          puts "  Cost: $#{result[:metadata][:cost_estimate] || 0.0}"
          puts "  Provider: #{result[:metadata][:provider]}"
        end
      end
      
      def show_help
        puts "📚 Available commands:"
        puts "  help                 - Show this help"
        puts "  providers            - List available providers"
        puts "  provider <name>      - Switch provider (openai, claude, gemini, cursor)"
        puts "  format <type>        - Switch format (markdown, ruby, json, html_partial)"
        puts "  exit                 - Quit chat"
        puts ""
        puts "💡 Just type your message to chat with the AI!"
      end
      
      def show_providers
        puts "🔧 Available providers:"
        RailsPlan::AI.available_providers.each do |provider|
          status = RailsPlan::AI.provider_available?(provider) ? "✅" : "❌"
          puts "  #{status} #{provider}"
        end
        puts ""
        puts "💡 Use 'provider <name>' to switch providers"
      end
      
      def suggest_alternatives(failed_provider)
        available = RailsPlan::AI.available_providers.select do |p|
          p != failed_provider && RailsPlan::AI.provider_available?(p)
        end
        
        if available.any?
          puts ""
          puts "💡 Try these available providers:"
          available.each { |p| puts "  railsplan chat --provider=#{p}" }
        else
          puts ""
          puts "💡 Configure AI providers in ~/.railsplan/ai.yml"
          puts "  Run: railsplan doctor"
        end
      end
    end
  end
end