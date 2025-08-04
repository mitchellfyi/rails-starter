# frozen_string_literal: true

module Railsplan
  module Web
    class ChatController < ApplicationController
      def index
        @chat_history = load_chat_history
        @context_summary = build_context_summary
      end
      
      def create
        message = params[:message].to_s.strip
        
        if message.blank?
          render json: { error: 'Message cannot be blank' }, status: :bad_request
          return
        end
        
        begin
          response = process_chat_message(message)
          
          # Log the chat interaction
          log_prompt(message, response, {
            type: 'chat',
            context_included: params[:include_context] == 'true'
          })
          
          render json: {
            success: true,
            response: response[:content],
            suggestions: response[:suggestions] || [],
            context_used: response[:context_used] || false
          }
        rescue => e
          Rails.logger.error "Chat failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Chat failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def context
        render json: {
          summary: build_context_summary,
          models: extract_model_names,
          controllers: extract_controller_names,
          routes: extract_route_info
        }
      end
      
      private
      
      def load_chat_history
        return [] unless File.exist?(prompt_logger)
        
        chats = []
        File.readlines(prompt_logger).each do |line|
          entry = JSON.parse(line.strip)
          if entry['metadata'] && entry['metadata']['type'] == 'chat'
            chats << entry
          end
        rescue JSON::ParserError
          next
        end
        chats.reverse.first(20)
      end
      
      def build_context_summary
        return {} unless @app_context
        
        {
          app_name: @app_context['app_name'],
          models_count: (@app_context['models'] || []).length,
          generated_at: @app_context['generated_at'],
          ruby_version: RUBY_VERSION,
          rails_version: Rails::VERSION::STRING
        }
      end
      
      def extract_model_names
        return [] unless @app_context && @app_context['models']
        
        @app_context['models'].map { |m| m['class_name'] }.reject { |name| name == 'ApplicationRecord' }
      end
      
      def extract_controller_names
        controllers = []
        controller_path = Rails.root.join('app/controllers')
        
        if Dir.exist?(controller_path)
          Dir.glob(controller_path.join('**/*_controller.rb')).each do |file|
            controller_name = File.basename(file, '.rb').camelize
            controllers << controller_name unless controller_name == 'ApplicationController'
          end
        end
        
        controllers.sort
      end
      
      def extract_route_info
        return [] unless defined?(Rails.application)
        
        routes = []
        Rails.application.routes.routes.each do |route|
          next if route.verb.blank? || route.path.spec.to_s.start_with?('/rails/')
          
          routes << {
            verb: route.verb,
            path: route.path.spec.to_s,
            controller: route.requirements[:controller],
            action: route.requirements[:action]
          }
        end
        
        routes.uniq.first(50) # Limit to avoid huge payloads
      rescue
        []
      end
      
      def process_chat_message(message)
        # Determine if this is a context-aware question
        include_context = message.downcase.include?('model') || 
                         message.downcase.include?('controller') ||
                         message.downcase.include?('schema') ||
                         message.downcase.include?('database') ||
                         params[:include_context] == 'true'
        
        if include_context && @app_context
          process_context_aware_chat(message)
        else
          process_general_chat(message)
        end
      end
      
      def process_context_aware_chat(message)
        # Build context for the AI
        context_info = {
          app_name: @app_context['app_name'],
          models: (@app_context['models'] || []).map { |m| 
            {
              name: m['class_name'],
              associations: (m['associations'] || []).map { |a| "#{a['type']} :#{a['name']}" }
            }
          },
          controllers: extract_controller_names,
          ruby_version: RUBY_VERSION,
          rails_version: Rails::VERSION::STRING
        }
        
        # Use AI to generate contextual response
        if defined?(RailsPlan::AI) && ai_config&.configured?
          ai_response = generate_ai_response(message, context_info)
          {
            content: ai_response,
            context_used: true,
            suggestions: generate_follow_up_suggestions(message)
          }
        else
          {
            content: generate_fallback_response(message, context_info),
            context_used: true,
            suggestions: []
          }
        end
      end
      
      def process_general_chat(message)
        # Handle general questions without app context
        if defined?(RailsPlan::AI) && ai_config&.configured?
          ai_response = generate_ai_response(message)
          {
            content: ai_response,
            context_used: false,
            suggestions: generate_general_suggestions(message)
          }
        else
          {
            content: generate_fallback_response(message),
            context_used: false,
            suggestions: []
          }
        end
      end
      
      def generate_ai_response(message, context = nil)
        # Use existing AI infrastructure
        begin
          ai = RailsPlan::AI.new(ai_config) if defined?(RailsPlan::AI)
          
          if ai && context
            prompt = build_contextual_prompt(message, context)
            response = ai.chat(prompt)
          elsif ai
            response = ai.chat(message)
          else
            return generate_fallback_response(message, context)
          end
          
          response.dig('choices', 0, 'message', 'content') || response['content'] || 'I apologize, but I couldn\'t generate a response.'
        rescue => e
          Rails.logger.error "AI chat failed: #{e.message}" if defined?(Rails.logger)
          generate_fallback_response(message, context)
        end
      end
      
      def build_contextual_prompt(message, context)
        prompt = "You are an AI assistant helping with a Rails application.\n\n"
        prompt += "Application Context:\n"
        prompt += "- App Name: #{context[:app_name]}\n"
        prompt += "- Ruby Version: #{context[:ruby_version]}\n"
        prompt += "- Rails Version: #{context[:rails_version]}\n"
        
        if context[:models].any?
          prompt += "- Models: #{context[:models].map { |m| m[:name] }.join(', ')}\n"
        end
        
        if context[:controllers].any?
          prompt += "- Controllers: #{context[:controllers].first(5).join(', ')}\n"
        end
        
        prompt += "\nUser Question: #{message}\n\n"
        prompt += "Please provide a helpful response specific to this Rails application."
        
        prompt
      end
      
      def generate_fallback_response(message, context = nil)
        # Generate helpful responses without AI
        message_lower = message.downcase
        
        if message_lower.include?('model') && context
          models = context.dig(:models) || extract_model_names
          if models.any?
            "I can see you have these models in your application: #{models.join(', ')}. What would you like to know about them?"
          else
            "I don't see any models in your application context. You might need to run 'railsplan index' to refresh the context."
          end
        elsif message_lower.include?('controller') && context
          controllers = context.dig(:controllers) || extract_controller_names
          if controllers.any?
            "Your application has these controllers: #{controllers.first(5).join(', ')}#{controllers.length > 5 ? ' and others' : ''}. What would you like to know?"
          else
            "No controllers found in the current context."
          end
        elsif message_lower.include?('help') || message_lower.include?('what can you do')
          "I can help you with:\n• Explaining your Rails application structure\n• Generating code with AI\n• Running diagnostics\n• Exploring your schema\n• Replaying previous prompts\n\nWhat would you like to do?"
        elsif message_lower.include?('version')
          "Your application is running Ruby #{RUBY_VERSION} and Rails #{Rails::VERSION::STRING}."
        else
          "I understand you're asking about: #{message}. For AI-powered responses, please configure AI providers in ~/.railsplan/ai.yml. Meanwhile, I can help with basic Rails questions and show you around the RailsPlan dashboard."
        end
      end
      
      def generate_follow_up_suggestions(message)
        message_lower = message.downcase
        
        if message_lower.include?('model')
          [
            "Show me the associations for a specific model",
            "Generate a new model with associations",
            "Explain the database schema"
          ]
        elsif message_lower.include?('controller')
          [
            "Generate a new controller",
            "Add actions to an existing controller",
            "Show me the routes"
          ]
        elsif message_lower.include?('test')
          [
            "Generate tests for my models",
            "Create controller tests",
            "Run diagnostic checks"
          ]
        else
          [
            "Explain my application structure",
            "Generate new code",
            "Run health diagnostics"
          ]
        end
      end
      
      def generate_general_suggestions(message)
        [
          "Tell me about my Rails application",
          "Help me generate new code",
          "Run diagnostics on my app",
          "Show me my database schema"
        ]
      end
    end
  end
end