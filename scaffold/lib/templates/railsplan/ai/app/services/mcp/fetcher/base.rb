# frozen_string_literal: true

module Mcp
  module Fetcher
    # Base class for all MCP fetchers. Provides common interface and utilities
    # for fetching data from various sources to enrich LLM prompts.
    #
    # Subclasses should implement:
    # - self.fetch(**params) - Main fetch method
    # - self.allowed_params (optional) - List of allowed parameter keys
    # - self.fallback_data(**params) (optional) - Fallback data when fetch fails
    #
    # Example:
    #   class MyFetcher < Mcp::Fetcher::Base
    #     def self.allowed_params
    #       [:user, :limit]
    #     end
    #
    #     def self.fetch(user:, limit: 10, **)
    #       # Fetch and return data
    #       { data: "fetched data for #{user.name}" }
    #     end
    #
    #     def self.fallback_data(**)
    #       { data: "fallback data" }
    #     end
    #   end
    class Base
      class << self
        # Main fetch method - to be implemented by subclasses
        # @param params [Hash] Parameters for fetching data
        # @return [Hash] Fetched data
        # @raise [NotImplementedError] If not implemented by subclass
        def fetch(**params)
          raise NotImplementedError, "#{self} must implement #fetch"
        end

        # Get list of allowed parameters for this fetcher
        # Override in subclasses to define parameter validation
        # @return [Array<Symbol>] List of allowed parameter keys
        def allowed_params
          []
        end

        # Provide fallback data when fetch fails
        # Override in subclasses to provide meaningful fallback
        # @param params [Hash] Same parameters passed to fetch
        # @return [Hash] Fallback data
        def fallback_data(**params)
          {}
        end

        # Validate parameters against allowed_params list
        # @param params [Hash] Parameters to validate
        # @raise [ArgumentError] If invalid parameters are provided
        def validate_params!(params)
          return if allowed_params.empty?

          invalid_keys = params.keys - allowed_params
          if invalid_keys.any?
            raise ArgumentError, "Invalid parameters: #{invalid_keys.join(', ')}. Allowed: #{allowed_params.join(', ')}"
          end
        end

        # Safe fetch with parameter validation and error handling
        # @param params [Hash] Parameters for fetching data
        # @return [Hash] Fetched data or fallback data on error
        def safe_fetch(**params)
          validate_params!(params)
          fetch(**params)
        rescue => e
          Rails.logger.error("#{self} fetch failed: #{e.message}")
          fallback_data(**params)
        end

        # Get fetcher metadata for introspection
        # @return [Hash] Metadata about the fetcher
        def metadata
          {
            name: name,
            allowed_params: allowed_params,
            has_fallback: respond_to?(:fallback_data),
            description: description
          }
        end

        # Description of what this fetcher does
        # Override in subclasses to provide documentation
        # @return [String] Description of the fetcher
        def description
          "Generic data fetcher"
        end

        # Check if a parameter is required
        # Override in subclasses to define required parameters
        # @param param [Symbol] Parameter name
        # @return [Boolean] True if parameter is required
        def required_param?(param)
          false
        end

        # Get list of required parameters
        # @return [Array<Symbol>] List of required parameter keys
        def required_params
          allowed_params.select { |param| required_param?(param) }
        end

        # Validate that all required parameters are present
        # @param params [Hash] Parameters to validate
        # @raise [ArgumentError] If required parameters are missing
        def validate_required_params!(params)
          missing_params = required_params - params.keys
          if missing_params.any?
            raise ArgumentError, "Missing required parameters: #{missing_params.join(', ')}"
          end
        end

        # Full parameter validation (both allowed and required)
        # @param params [Hash] Parameters to validate
        def validate_all_params!(params)
          validate_params!(params)
          validate_required_params!(params)
        end
      end
    end
  end
end