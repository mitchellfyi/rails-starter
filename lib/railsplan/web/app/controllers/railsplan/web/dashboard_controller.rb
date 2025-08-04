# frozen_string_literal: true

module Railsplan
  module Web
    class DashboardController < ApplicationController
      def index
        @stats = gather_dashboard_stats
        @recent_prompts = load_recent_prompts
        @health_checks = run_basic_health_checks
        @modules = detect_installed_modules
      end
      
      private
      
      def gather_dashboard_stats
        {
          ruby_version: RUBY_VERSION,
          rails_version: Rails::VERSION::STRING,
          db_adapter: detect_db_adapter,
          app_name: detect_app_name,
          context_fresh: context_is_fresh?,
          last_indexed: last_index_time
        }
      end
      
      def detect_db_adapter
        return 'Unknown' unless defined?(ActiveRecord)
        ActiveRecord::Base.connection.adapter_name
      rescue
        'Unknown'
      end
      
      def detect_app_name
        @app_context&.dig('app_name') || Rails.application.class.module_parent_name
      end
      
      def context_is_fresh?
        return false unless @app_context
        
        context_time = Time.parse(@app_context['generated_at'])
        # Context is fresh if it's less than 1 hour old
        context_time > 1.hour.ago
      rescue
        false
      end
      
      def last_index_time
        return nil unless @app_context
        
        Time.parse(@app_context['generated_at']).strftime('%B %d, %Y at %I:%M %p')
      rescue
        'Unknown'
      end
      
      def load_recent_prompts
        return [] unless File.exist?(prompt_logger)
        
        prompts = []
        File.readlines(prompt_logger).last(10).each do |line|
          prompts << JSON.parse(line.strip)
        rescue JSON::ParserError
          next
        end
        prompts.reverse
      end
      
      def run_basic_health_checks
        checks = []
        
        # Check if context exists
        unless @app_context
          checks << {
            type: 'warning',
            title: 'No Context Available',
            description: 'Run "railsplan index" to extract application context'
          }
        end
        
        # Check if context is stale
        unless context_is_fresh?
          checks << {
            type: 'info',
            title: 'Context May Be Stale',
            description: 'Consider running "railsplan index" to refresh context'
          }
        end
        
        # Check AI configuration
        unless ai_config.configured?
          checks << {
            type: 'warning',
            title: 'AI Not Configured',
            description: 'Configure AI providers in ~/.railsplan/ai.yml'
          }
        end
        
        checks
      end
      
      def detect_installed_modules
        modules = []
        
        # Check for common modules by looking for their markers
        modules << { name: 'Authentication', installed: user_model_exists? }
        modules << { name: 'AI Integration', installed: ai_integration_exists? }
        modules << { name: 'Admin Panel', installed: admin_panel_exists? }
        modules << { name: 'API', installed: api_exists? }
        
        modules
      end
      
      def user_model_exists?
        defined?(User) || File.exist?(Rails.root.join('app/models/user.rb'))
      end
      
      def ai_integration_exists?
        File.exist?(Rails.root.join('.railsplan/ai.yml'))
      end
      
      def admin_panel_exists?
        File.exist?(Rails.root.join('app/controllers/admin'))
      end
      
      def api_exists?
        File.exist?(Rails.root.join('app/controllers/api'))
      end
    end
  end
end