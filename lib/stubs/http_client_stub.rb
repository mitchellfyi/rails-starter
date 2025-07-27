# frozen_string_literal: true

require 'json'
require 'digest'
require 'uri'

module Stubs
  # Stub client for HTTP API calls in test environment
  # Returns deterministic, predictable responses for testing
  class HttpClientStub
    def initialize
      # Store registered mock responses
      @mock_responses = {}
      @request_log = []
    end

    # Register a mock response for a specific URL pattern
    def register_mock(url_pattern, response_data)
      @mock_responses[url_pattern] = response_data
    end

    # Clear all registered mocks
    def clear_mocks
      @mock_responses.clear
      @request_log.clear
    end

    # Get request history for testing
    def request_log
      @request_log.dup
    end

    # Make HTTP request (stubbed)
    def request(method, url, headers: {}, body: nil, params: {})
      # Log the request
      @request_log << {
        method: method.to_s.upcase,
        url: url,
        headers: headers,
        body: body,
        params: params,
        timestamp: Time.now
      }

      # Check for registered mocks first
      mock_response = find_mock_response(url)
      return mock_response if mock_response

      # Generate deterministic response based on URL
      generate_deterministic_response(method, url, headers, body, params)
    end

    # Convenience methods for different HTTP verbs
    def get(url, headers: {}, params: {})
      request(:get, url, headers: headers, params: params)
    end

    def post(url, headers: {}, body: nil, params: {})
      request(:post, url, headers: headers, body: body, params: params)
    end

    def put(url, headers: {}, body: nil, params: {})
      request(:put, url, headers: headers, body: body, params: params)
    end

    def patch(url, headers: {}, body: nil, params: {})
      request(:patch, url, headers: headers, body: body, params: params)
    end

    def delete(url, headers: {}, params: {})
      request(:delete, url, headers: headers, params: params)
    end

    # Simulate network errors for testing
    def simulate_error(error_type = :timeout)
      case error_type
      when :timeout
        raise StandardError, "Request timeout"
      when :connection_error
        raise StandardError, "Connection refused"
      when :dns_error
        raise StandardError, "DNS resolution failed"
      when :ssl_error
        raise StandardError, "SSL certificate verification failed"
      else
        raise StandardError, "Network error"
      end
    end

    # Check if URL was requested
    def requested?(url, method: nil)
      @request_log.any? do |request|
        url_match = request[:url] == url || request[:url].include?(url)
        method_match = method.nil? || request[:method] == method.to_s.upcase
        url_match && method_match
      end
    end

    # Get count of requests to a URL
    def request_count(url, method: nil)
      @request_log.count do |request|
        url_match = request[:url] == url || request[:url].include?(url)
        method_match = method.nil? || request[:method] == method.to_s.upcase
        url_match && method_match
      end
    end

    private

    # Find matching mock response
    def find_mock_response(url)
      @mock_responses.each do |pattern, response|
        if pattern.is_a?(Regexp)
          return response if url.match?(pattern)
        elsif pattern.is_a?(String)
          return response if url.include?(pattern)
        end
      end
      nil
    end

    # Generate deterministic response based on URL and request details
    def generate_deterministic_response(method, url, headers, body, params)
      uri = URI.parse(url)
      
      # Generate deterministic response based on URL characteristics
      response_data = if uri.host&.include?('github.com')
                        generate_github_response(method, uri.path, params)
                      elsif uri.host&.include?('api.openai.com')
                        generate_openai_response(method, uri.path, body)
                      elsif uri.host&.include?('api.stripe.com')
                        generate_stripe_response(method, uri.path, body)
                      else
                        generate_generic_response(method, url, body)
                      end

      {
        status: response_data[:status] || 200,
        success: (response_data[:status] || 200).between?(200, 299),
        headers: response_data[:headers] || { 'content-type' => 'application/json' },
        body: response_data[:body],
        data: response_data[:data],
        url: url,
        cached: false,
        fetched_at: Time.now
      }
    end

    # Generate GitHub API response
    def generate_github_response(method, path, params)
      case path
      when %r{^/users/(\w+)$}
        username = Regexp.last_match(1)
        {
          status: 200,
          data: {
            'login' => username,
            'id' => deterministic_id(username),
            'name' => username.capitalize,
            'bio' => "Test user #{username} - deterministic response",
            'public_repos' => deterministic_count(username, 'repos'),
            'followers' => deterministic_count(username, 'followers'),
            'following' => deterministic_count(username, 'following'),
            'created_at' => '2023-01-01T00:00:00Z',
            'updated_at' => '2023-12-01T00:00:00Z'
          }
        }
      when %r{^/users/(\w+)/repos$}
        username = Regexp.last_match(1)
        per_page = params[:per_page] || 30
        repo_count = [deterministic_count(username, 'repos'), per_page.to_i].min
        
        repos = (1..repo_count).map do |i|
          repo_name = "#{username}-repo-#{i}"
          {
            'name' => repo_name,
            'full_name' => "#{username}/#{repo_name}",
            'description' => "Test repository #{i} for #{username}",
            'language' => determine_language(i),
            'stargazers_count' => deterministic_count("#{username}-#{repo_name}", 'stars'),
            'forks_count' => deterministic_count("#{username}-#{repo_name}", 'forks'),
            'updated_at' => '2023-12-01T00:00:00Z'
          }
        end
        
        { status: 200, data: repos }
      else
        { status: 404, data: { 'message' => 'Not Found' } }
      end
    end

    # Generate OpenAI API response
    def generate_openai_response(method, path, body)
      case path
      when '/v1/chat/completions'
        request_data = body.is_a?(String) ? JSON.parse(body) : body || {}
        model = request_data['model'] || 'gpt-3.5-turbo'
        messages = request_data['messages'] || []
        
        user_message = messages.find { |m| m['role'] == 'user' }&.dig('content') || ''
        response_text = generate_deterministic_ai_response(user_message, model)
        
        {
          status: 200,
          data: {
            'id' => 'chatcmpl-stub123',
            'object' => 'chat.completion',
            'created' => Time.now.to_i,
            'model' => model,
            'choices' => [
              {
                'index' => 0,
                'message' => {
                  'role' => 'assistant',
                  'content' => response_text
                },
                'finish_reason' => 'stop'
              }
            ]
          }
        }
      when '/v1/models'
        {
          status: 200,
          data: {
            'object' => 'list',
            'data' => [
              { 'id' => 'gpt-4', 'object' => 'model', 'owned_by' => 'openai' },
              { 'id' => 'gpt-3.5-turbo', 'object' => 'model', 'owned_by' => 'openai' }
            ]
          }
        }
      else
        { status: 404, data: { 'error' => 'Not found' } }
      end
    end

    # Generate Stripe API response
    def generate_stripe_response(method, path, body)
      case path
      when '/v1/customers'
        if method.upcase == 'POST'
          request_data = parse_form_data(body)
          email = request_data['email'] || 'test@example.com'
          
          {
            status: 200,
            data: {
              'id' => "cus_#{Digest::MD5.hexdigest(email)[0..14]}",
              'object' => 'customer',
              'email' => email,
              'created' => Time.now.to_i
            }
          }
        else
          { status: 200, data: { 'object' => 'list', 'data' => [] } }
        end
      else
        { status: 404, data: { 'error' => 'Not found' } }
      end
    end

    # Generate generic API response
    def generate_generic_response(method, url, body)
      url_hash = Digest::MD5.hexdigest(url)[0..6]
      
      {
        status: 200,
        data: {
          'message' => "Deterministic test response for #{method.upcase} #{url}",
          'url_hash' => url_hash,
          'timestamp' => Time.now.iso8601,
          'method' => method.to_s.upcase,
          'test_mode' => true
        }
      }
    end

    # Utility methods
    def deterministic_id(input)
      Digest::MD5.hexdigest(input.to_s).to_i(16) % 1000000
    end

    def deterministic_count(input, count_type)
      hash = Digest::MD5.hexdigest("#{input}-#{count_type}").to_i(16)
      case count_type
      when 'repos'
        (hash % 50) + 1
      when 'followers', 'following'
        hash % 1000
      when 'stars'
        hash % 500
      when 'forks'
        hash % 100
      else
        hash % 100
      end
    end

    def determine_language(index)
      languages = ['Ruby', 'JavaScript', 'Python', 'Go', 'Java', 'TypeScript']
      languages[index % languages.length]
    end

    def generate_deterministic_ai_response(input, model)
      input_hash = Digest::MD5.hexdigest(input.to_s)[0..6]
      "Deterministic AI response from #{model} for input hash #{input_hash}: #{input[0..50]}..."
    end

    def parse_form_data(body)
      return {} unless body.is_a?(String)
      
      URI.decode_www_form(body).to_h
    rescue
      {}
    end
  end
end