# frozen_string_literal: true

# Synth MCP (Multi-Context Provider) module installer.
# This module creates a flexible context provider system for AI prompts.

say_status :mcp, "Installing Multi-Context Provider system"

# Add MCP-specific gems
add_gem 'httparty', '~> 0.22'
add_gem 'faraday', '~> 2.7'
add_gem 'redis', '~> 5.0'

after_bundle do
  # Create MCP configuration
  initializer 'mcp.rb', <<~'RUBY'
    Rails.application.config.mcp = ActiveSupport::OrderedOptions.new
    Rails.application.config.mcp.cache_ttl = 5.minutes
    Rails.application.config.mcp.timeout = 30.seconds
    Rails.application.config.mcp.max_retries = 3
  RUBY

  # Generate MCP models
  generate 'model', 'ContextProvider', 'name:string', 'provider_type:string', 'configuration:json', 'active:boolean', 'description:text'
  generate 'model', 'ContextCache', 'key:string', 'data:json', 'expires_at:datetime', 'provider:string'

  # Create base context provider
  create_file 'app/services/context_providers/base_provider.rb', <<~'RUBY'
    module ContextProviders
      class BaseProvider
        attr_reader :config, :params

        def initialize(config = {}, params = {})
          @config = config.with_indifferent_access
          @params = params.with_indifferent_access
        end

        def fetch
          cache_key = generate_cache_key
          
          if cached_data = get_cached_data(cache_key)
            return cached_data
          end

          data = fetch_data
          cache_data(cache_key, data) if data
          data
        rescue => e
          Rails.logger.error "Context provider error: #{e.message}"
          handle_error(e)
        end

        private

        def fetch_data
          raise NotImplementedError, "Subclasses must implement fetch_data"
        end

        def generate_cache_key
          "mcp:#{self.class.name.demodulize.underscore}:#{params.to_query}"
        end

        def get_cached_data(key)
          cache_record = ContextCache.find_by(key: key)
          return nil unless cache_record
          return nil if cache_record.expires_at < Time.current

          cache_record.data
        end

        def cache_data(key, data)
          ContextCache.find_or_create_by(key: key) do |record|
            record.data = data
            record.expires_at = Rails.application.config.mcp.cache_ttl.from_now
            record.provider = self.class.name
          end
        end

        def handle_error(error)
          { error: error.message, provider: self.class.name }
        end
      end
    end
  RUBY

  # Create database context provider
  create_file 'app/services/context_providers/database_provider.rb', <<~'RUBY'
    module ContextProviders
      class DatabaseProvider < BaseProvider
        def fetch_data
          model = params[:model]&.constantize
          return { error: "Invalid model" } unless model

          case params[:query_type]
          when 'find'
            record = model.find_by(id: params[:id])
            record ? record.attributes : { error: "Record not found" }
          when 'recent'
            limit = params[:limit] || 10
            model.limit(limit).order(created_at: :desc).pluck(:id, :created_at)
          when 'count'
            { count: model.count }
          when 'custom'
            execute_custom_query
          else
            { error: "Unknown query type" }
          end
        end

        private

        def execute_custom_query
          return { error: "No custom query provided" } unless params[:sql]
          
          # Basic safety check - only allow SELECT statements
          unless params[:sql].strip.downcase.start_with?('select')
            return { error: "Only SELECT queries allowed" }
          end

          result = ActiveRecord::Base.connection.execute(params[:sql])
          result.to_a
        rescue => e
          { error: "Query execution failed: #{e.message}" }
        end
      end
    end
  RUBY

  # Create API context provider
  create_file 'app/services/context_providers/api_provider.rb', <<~'RUBY'
    module ContextProviders
      class ApiProvider < BaseProvider
        include HTTParty

        def fetch_data
          url = build_url
          headers = build_headers
          
          response = case params[:method]&.downcase || 'get'
          when 'get'
            self.class.get(url, headers: headers, timeout: timeout)
          when 'post'
            self.class.post(url, headers: headers, body: params[:body], timeout: timeout)
          else
            return { error: "Unsupported HTTP method" }
          end

          if response.success?
            parse_response(response)
          else
            { error: "API request failed", status: response.code, message: response.message }
          end
        end

        private

        def build_url
          base_url = config[:base_url] || params[:url]
          endpoint = params[:endpoint] || ''
          query_params = params[:query] || {}

          url = URI.join(base_url.to_s, endpoint.to_s).to_s
          url += "?#{query_params.to_query}" if query_params.any?
          url
        end

        def build_headers
          default_headers = {
            'User-Agent' => 'Synth-MCP/1.0',
            'Accept' => 'application/json'
          }
          
          auth_headers = build_auth_headers
          custom_headers = params[:headers] || {}
          
          default_headers.merge(auth_headers).merge(custom_headers)
        end

        def build_auth_headers
          case config[:auth_type]
          when 'bearer'
            { 'Authorization' => "Bearer #{config[:token]}" }
          when 'api_key'
            { config[:api_key_header] || 'X-API-Key' => config[:api_key] }
          when 'basic'
            encoded = Base64.encode64("#{config[:username]}:#{config[:password]}").chomp
            { 'Authorization' => "Basic #{encoded}" }
          else
            {}
          end
        end

        def parse_response(response)
          case response.headers['content-type']&.downcase
          when /json/
            response.parsed_response
          when /xml/
            Hash.from_xml(response.body)
          else
            { content: response.body, content_type: response.headers['content-type'] }
          end
        end

        def timeout
          config[:timeout] || Rails.application.config.mcp.timeout.to_i
        end
      end
    end
  RUBY

  # Create MCP service
  create_file 'app/services/mcp_service.rb', <<~'RUBY'
    class McpService
      attr_reader :context

      def initialize
        @context = {}
      end

      def fetch(key, provider_config = {})
        provider = create_provider(provider_config)
        data = provider.fetch
        @context[key.to_sym] = data
        data
      end

      def get(key)
        @context[key.to_sym]
      end

      def merge(additional_context)
        @context.merge!(additional_context.symbolize_keys)
      end

      def to_h
        @context
      end

      def clear
        @context.clear
      end

      private

      def create_provider(config)
        provider_type = config[:type] || config['type'] || 'database'
        provider_class = "ContextProviders::#{provider_type.classify}Provider".constantize
        
        provider_config = config[:config] || config['config'] || {}
        params = config[:params] || config['params'] || {}
        
        provider_class.new(provider_config, params)
      rescue NameError
        raise ArgumentError, "Unknown provider type: #{provider_type}"
      end
    end
  RUBY

  # Create MCP controller
  create_file 'app/controllers/mcp_controller.rb', <<~'RUBY'
    class McpController < ApplicationController
      before_action :authenticate_user!

      def test
        mcp = McpService.new
        
        # Example: Fetch recent users
        mcp.fetch(:recent_users, {
          type: 'database',
          params: { model: 'User', query_type: 'recent', limit: 5 }
        })

        # Example: Fetch from API
        if params[:api_url].present?
          mcp.fetch(:api_data, {
            type: 'api',
            params: { url: params[:api_url], method: 'get' }
          })
        end

        render json: { context: mcp.to_h, status: 'success' }
      rescue => e
        render json: { error: e.message, status: 'error' }, status: :unprocessable_entity
      end
    end
  RUBY

  say_status :mcp, "MCP module installed. Next steps:"
  say_status :mcp, "1. Run rails db:migrate"
  say_status :mcp, "2. Add MCP routes"
  say_status :mcp, "3. Configure context providers"
  say_status :mcp, "4. Test with bin/synth test mcp"
end