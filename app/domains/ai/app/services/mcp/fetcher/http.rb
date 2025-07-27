# frozen_string_literal: true

require 'net/http'
require 'json'
require_relative '../../../../../../lib/api_client_factory'

module Mcp
  module Fetcher
    # HTTP fetcher for making requests to external APIs like GitHub, Slack, etc.
    # Includes rate limiting, error handling, and response caching.
    #
    # Example:
    #   # Register for GitHub API
    #   Mcp::Registry.register(:github_repo, Mcp::Fetcher::Http)
    #
    #   # Use in context
    #   context.fetch(:github_repo,
    #     url: 'https://api.github.com/repos/rails/rails',
    #     headers: { 'Authorization' => "token #{github_token}" },
    #     cache_key: 'github_rails_repo',
    #     cache_ttl: 1.hour
    #   )
    class Http < Base
      def self.allowed_params
        [:url, :method, :headers, :body, :params, :timeout, :follow_redirects, 
         :cache_key, :cache_ttl, :rate_limit_key, :max_retries]
      end

      def self.required_params
        [:url]
      end

      def self.required_param?(param)
        required_params.include?(param)
      end

      def self.description
        "Fetches data from external HTTP APIs with rate limiting and caching"
      end

      def self.fetch(url:, method: :get, headers: {}, body: nil, params: {}, timeout: 30, 
                     follow_redirects: true, cache_key: nil, cache_ttl: 5.minutes,
                     rate_limit_key: nil, max_retries: 3, **)
        validate_all_params!(
          url: url, method: method, headers: headers, body: body, params: params,
          timeout: timeout, follow_redirects: follow_redirects, cache_key: cache_key,
          cache_ttl: cache_ttl, rate_limit_key: rate_limit_key, max_retries: max_retries
        )

        # Use stub client in test environment
        if ApiClientFactory.stub_mode?
          client = ApiClientFactory.http_client
          return client.request(method, url, headers: headers, body: body, params: params)
        end

        # Check rate limiting (only in non-test environments)
        if rate_limit_key && rate_limited?(rate_limit_key)
          raise StandardError, "Rate limit exceeded for #{rate_limit_key}"
        end

        # Check cache first (only in non-test environments)
        if cache_key && cached_response = get_cached_response(cache_key)
          Rails.logger.info("MCP HTTP: Using cached response for #{cache_key}")
          return cached_response
        end

        # Make the HTTP request with retries (only in non-test environments)
        response_data = nil
        max_retries.times do |attempt|
          begin
            response_data = make_http_request(url, method, headers, body, params, timeout, follow_redirects)
            break # Success, exit retry loop
          rescue => e
            if attempt == max_retries - 1
              raise e # Last attempt, re-raise the error
            else
              Rails.logger.warn("MCP HTTP: Attempt #{attempt + 1} failed for #{url}: #{e.message}")
              sleep(2 ** attempt) # Exponential backoff
            end
          end
        end

        # Update rate limiting
        update_rate_limit(rate_limit_key) if rate_limit_key

        # Cache the response
        cache_response(cache_key, response_data, cache_ttl) if cache_key

        response_data
      end

      def self.fallback_data(url: nil, **)
        {
          url: url,
          status: 'error',
          error: 'Failed to fetch data from HTTP API',
          data: nil,
          cached: false
        }
      end

      private

      # Make the actual HTTP request
      def self.make_http_request(url, method, headers, body, params, timeout, follow_redirects)
        uri = URI(url)
        
        # Add query parameters
        if params.present? && method.to_s.downcase == 'get'
          uri.query = URI.encode_www_form(params)
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = timeout
        http.open_timeout = timeout

        # Create request
        request_class = case method.to_s.downcase
                       when 'get' then Net::HTTP::Get
                       when 'post' then Net::HTTP::Post
                       when 'put' then Net::HTTP::Put
                       when 'patch' then Net::HTTP::Patch
                       when 'delete' then Net::HTTP::Delete
                       else
                         raise ArgumentError, "Unsupported HTTP method: #{method}"
                       end

        request = request_class.new(uri)
        
        # Set headers
        headers.each { |key, value| request[key] = value }
        request['User-Agent'] ||= 'Rails-MCP-Fetcher/1.0'
        request['Accept'] ||= 'application/json'

        # Set body for non-GET requests
        if body && !['get', 'head'].include?(method.to_s.downcase)
          request.body = body.is_a?(Hash) ? body.to_json : body.to_s
          request['Content-Type'] ||= 'application/json' if body.is_a?(Hash)
        end

        # Make request
        response = http.request(request)

        # Handle redirects
        if follow_redirects && response.code.to_i.between?(300, 399) && response['location']
          redirect_count = 0
          while redirect_count < 5 && response.code.to_i.between?(300, 399) && response['location']
            uri = URI(response['location'])
            request = request_class.new(uri)
            headers.each { |key, value| request[key] = value }
            response = http.request(request)
            redirect_count += 1
          end
        end

        # Parse response
        parse_response(response, url)
      end

      # Parse HTTP response
      def self.parse_response(response, url)
        status_code = response.code.to_i
        content_type = response['content-type'] || ''
        
        # Parse JSON if content type indicates JSON
        data = if content_type.include?('application/json') || content_type.include?('text/json')
                 begin
                   JSON.parse(response.body)
                 rescue JSON::ParserError => e
                   Rails.logger.warn("MCP HTTP: Failed to parse JSON from #{url}: #{e.message}")
                   response.body
                 end
               else
                 response.body
               end

        {
          url: url,
          status: status_code,
          success: status_code.between?(200, 299),
          headers: response.to_hash,
          data: data,
          content_type: content_type,
          cached: false,
          fetched_at: Time.current
        }
      end

      # Class-level attribute for default rate limit
      @default_rate_limit = 100

      # Set default rate limit
      def self.default_rate_limit=(limit)
        @default_rate_limit = limit
      end

      # Get default rate limit
      def self.default_rate_limit
        @default_rate_limit
      end

      # Check if rate limited
      def self.rate_limited?(rate_limit_key)
        return false unless Rails.cache # No caching available

        cache_key = "mcp_http_rate_limit:#{rate_limit_key}"
        count = Rails.cache.read(cache_key) || 0
        count >= @default_rate_limit # Use configurable rate limit
      end

      # Update rate limit counter
      def self.update_rate_limit(rate_limit_key)
        return unless Rails.cache

        cache_key = "mcp_http_rate_limit:#{rate_limit_key}"
        current_count = Rails.cache.read(cache_key) || 0
        Rails.cache.write(cache_key, current_count + 1, expires_in: 1.hour)
      end

      # Get cached response
      def self.get_cached_response(cache_key)
        return nil unless Rails.cache

        full_cache_key = "mcp_http_cache:#{cache_key}"
        cached = Rails.cache.read(full_cache_key)
        cached&.merge(cached: true)
      end

      # Cache response
      def self.cache_response(cache_key, response_data, cache_ttl)
        return unless Rails.cache && response_data[:success]

        full_cache_key = "mcp_http_cache:#{cache_key}"
        Rails.cache.write(full_cache_key, response_data, expires_in: cache_ttl)
      end
    end
  end
end