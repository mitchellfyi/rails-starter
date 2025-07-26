# frozen_string_literal: true

module Mcp
  # Context API that holds base data (like current user) and provides
  # a unified interface for fetching data from various sources to enrich
  # LLM prompts. Context can combine multiple fetcher calls and merge
  # results into a single hash.
  #
  # Example:
  #   context = Mcp::Context.new(user: current_user, workspace: current_workspace)
  #   context.fetch(:recent_orders, limit: 5)
  #   context.fetch(:github_repo, repo: 'rails/rails')
  #   prompt_data = context.to_h
  class Context
    attr_reader :base_data, :fetched_data, :errors

    # Initialize context with base data
    # @param base_data [Hash] Base context data (user, workspace, etc.)
    def initialize(**base_data)
      @base_data = base_data.freeze
      @fetched_data = {}
      @errors = {}
    end

    # Fetch data using a registered fetcher
    # @param key [Symbol] The fetcher key
    # @param params [Hash] Parameters to pass to the fetcher
    # @return [Hash] The fetched data
    # @raise [ArgumentError] If fetcher is not registered
    def fetch(key, **params)
      fetcher_class = Mcp::Registry.get(key)
      raise ArgumentError, "No fetcher registered for key: #{key}" unless fetcher_class

      # Merge base data with passed parameters
      fetch_params = base_data.merge(params)

      begin
        data = fetcher_class.fetch(**fetch_params)
        @fetched_data[key] = data
        Rails.logger.info("MCP: Successfully fetched data for '#{key}'")
        data
      rescue => e
        error_message = "Failed to fetch data for '#{key}': #{e.message}"
        @errors[key] = error_message
        Rails.logger.error("MCP: #{error_message}")
        
        # Return fallback data if fetcher provides it
        if fetcher_class.respond_to?(:fallback_data)
          fallback = fetcher_class.fallback_data(**fetch_params)
          @fetched_data[key] = fallback
          fallback
        else
          {}
        end
      end
    end

    # Fetch multiple keys at once
    # @param keys_and_params [Array<Array>] Array of [key, params] pairs
    # @return [Hash] Combined results from all fetchers
    def fetch_multiple(*keys_and_params)
      keys_and_params.each do |key_data|
        if key_data.is_a?(Array)
          key, params = key_data
          fetch(key, **(params || {}))
        else
          fetch(key_data)
        end
      end
      
      fetched_data
    end

    # Get all context data including base data and fetched data
    # @return [Hash] Combined context data
    def to_h
      base_data.merge(fetched_data)
    end

    # Get specific fetched data by key
    # @param key [Symbol] The fetcher key
    # @return [Object] The fetched data or nil if not found
    def [](key)
      fetched_data[key]
    end

    # Check if data was successfully fetched for a key
    # @param key [Symbol] The fetcher key
    # @return [Boolean] True if data exists and no error occurred
    def success?(key)
      fetched_data.key?(key) && !errors.key?(key)
    end

    # Check if there was an error fetching data for a key
    # @param key [Symbol] The fetcher key
    # @return [Boolean] True if there was an error
    def error?(key)
      errors.key?(key)
    end

    # Get error message for a specific key
    # @param key [Symbol] The fetcher key
    # @return [String, nil] Error message or nil if no error
    def error_message(key)
      errors[key]
    end

    # Check if any errors occurred during fetching
    # @return [Boolean] True if any errors occurred
    def has_errors?
      errors.any?
    end

    # Get list of successfully fetched keys
    # @return [Array<Symbol>] Array of keys that were successfully fetched
    def successful_keys
      fetched_data.keys - errors.keys
    end

    # Get list of keys that had errors
    # @return [Array<Symbol>] Array of keys that had errors
    def error_keys
      errors.keys
    end

    # Reset all fetched data and errors
    def reset!
      @fetched_data = {}
      @errors = {}
    end
  end
end