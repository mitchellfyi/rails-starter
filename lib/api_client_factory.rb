# frozen_string_literal: true

# Factory for creating API clients that returns stub clients in test environment
# and real clients in development/production
#
# Usage:
#   client = ApiClientFactory.openai_client
#   client = ApiClientFactory.stripe_client
#   client = ApiClientFactory.github_client
#
class ApiClientFactory
  class << self
    # Get OpenAI client (stub in test, real in other environments)
    def openai_client
      if Rails.env.test?
        require_relative 'stubs/openai_client_stub'
        Stubs::OpenAIClientStub.new
      else
        # Return real OpenAI client in non-test environments
        # This would be implemented with actual OpenAI gem
        raise NotImplementedError, "Real OpenAI client not implemented yet"
      end
    end

    # Get Stripe client (stub in test, real in other environments)
    def stripe_client
      if Rails.env.test?
        require_relative 'stubs/stripe_client_stub'
        Stubs::StripeClientStub.new
      else
        # Return real Stripe client in non-test environments
        require 'stripe'
        Stripe
      end
    end

    # Get GitHub client (stub in test, real in other environments)
    def github_client
      if Rails.env.test?
        require_relative 'stubs/github_client_stub'
        Stubs::GitHubClientStub.new
      else
        # Return real GitHub client in non-test environments
        # This would be implemented with octokit gem or similar
        raise NotImplementedError, "Real GitHub client not implemented yet"
      end
    end

    # Get HTTP client (stub in test, real in other environments)
    def http_client
      if Rails.env.test?
        require_relative 'stubs/http_client_stub'
        Stubs::HttpClientStub.new
      else
        # Return real HTTP client in non-test environments
        require 'net/http'
        Net::HTTP
      end
    end

    # Check if we're in stub mode
    def stub_mode?
      Rails.env.test?
    end
  end
end