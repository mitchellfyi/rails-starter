# frozen_string_literal: true

module Mcp
  # Central registry for managing fetchers that provide context data
  # for enriching LLM prompts. Fetchers can be registered under specific
  # keys and then invoked to retrieve data from various sources.
  #
  # Example:
  #   Mcp::Registry.register(:recent_orders, Mcp::Fetcher::Database)
  #   Mcp::Registry.register(:github_repo, Mcp::Fetcher::Http)
  #
  #   fetcher = Mcp::Registry.get(:recent_orders)
  #   data = fetcher.fetch(user: current_user, limit: 10)
  class Registry
    class << self
      # Get all registered fetchers
      # @return [Hash] Hash of fetcher_key => fetcher_class
      def all
        @fetchers ||= {}
      end

      # Register a fetcher class under a specific key
      # @param key [Symbol] The key to register the fetcher under
      # @param fetcher_class [Class] The fetcher class to register
      # @raise [ArgumentError] If key is not a symbol or fetcher_class is invalid
      def register(key, fetcher_class)
        raise ArgumentError, "Key must be a symbol" unless key.is_a?(Symbol)
        raise ArgumentError, "Fetcher must respond to :fetch" unless fetcher_class.respond_to?(:fetch)

        all[key] = fetcher_class
        Rails.logger.info("MCP: Registered fetcher '#{key}' => #{fetcher_class}")
      end

      # Get a fetcher by key
      # @param key [Symbol] The fetcher key
      # @return [Class, nil] The fetcher class or nil if not found
      def get(key)
        all[key]
      end

      # Check if a fetcher is registered
      # @param key [Symbol] The fetcher key
      # @return [Boolean] True if the fetcher is registered
      def registered?(key)
        all.key?(key)
      end

      # Unregister a fetcher
      # @param key [Symbol] The fetcher key to remove
      # @return [Class, nil] The removed fetcher class or nil if not found
      def unregister(key)
        all.delete(key).tap do |removed|
          Rails.logger.info("MCP: Unregistered fetcher '#{key}'") if removed
        end
      end

      # Clear all registered fetchers (mainly for testing)
      def clear!
        @fetchers = {}
      end

      # Get list of registered fetcher keys
      # @return [Array<Symbol>] Array of registered keys
      def keys
        all.keys
      end
    end
  end
end