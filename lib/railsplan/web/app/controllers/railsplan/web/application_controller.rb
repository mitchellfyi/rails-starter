# frozen_string_literal: true

module Railsplan
  module Web
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
      
      layout 'railsplan/web/application'
      
      before_action :load_context
      before_action :check_railsplan_initialized
      
      private
      
      def load_context
        return unless defined?(RailsPlan::ContextManager)
        
        @context_manager = RailsPlan::ContextManager.new
        @app_context = @context_manager.load_context if @context_manager.context_exists?
      rescue => e
        Rails.logger.error "Failed to load context: #{e.message}" if defined?(Rails.logger)
        @app_context = nil
      end
      
      def check_railsplan_initialized
        unless File.exist?(Rails.root.join('.railsplan'))
          redirect_to_initialization_guide
        end
      end
      
      def redirect_to_initialization_guide
        flash[:notice] = "RailsPlan needs to be initialized. Run 'railsplan init' in your terminal."
        render 'railsplan/web/shared/not_initialized', layout: 'railsplan/web/application'
      end
      
      def ai_config
        return unless defined?(RailsPlan::AIConfig)
        @ai_config ||= RailsPlan::AIConfig.new
      rescue
        nil
      end
      
      def prompt_logger
        @prompt_logger ||= File.join(Rails.root, '.railsplan', 'prompts.log')
      end
      
      def log_prompt(prompt, response, metadata = {})
        return unless File.exist?(File.dirname(prompt_logger))
        
        log_entry = {
          timestamp: Time.current.iso8601,
          prompt: prompt,
          response: response,
          metadata: metadata
        }
        
        File.open(prompt_logger, 'a') do |f|
          f.puts JSON.generate(log_entry)
        end
      end
    end
  end
end