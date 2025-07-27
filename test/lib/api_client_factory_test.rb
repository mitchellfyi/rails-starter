# frozen_string_literal: true

require_relative '../../lib/api_client_factory'
require 'minitest/autorun'

class ApiClientFactoryTest < Minitest::Test
  def setup
    @original_env = Rails.env if defined?(Rails)
  end

  def teardown
    if defined?(Rails) && @original_env
      Rails.env = @original_env
    end
  end

  def test_openai_client_returns_stub_in_test_environment
    simulate_test_environment do
      client = ApiClientFactory.openai_client
      assert_instance_of Stubs::OpenAIClientStub, client
    end
  end

  def test_github_client_returns_stub_in_test_environment
    simulate_test_environment do
      client = ApiClientFactory.github_client
      assert_instance_of Stubs::GitHubClientStub, client
    end
  end

  def test_stripe_client_returns_stub_in_test_environment
    simulate_test_environment do
      client = ApiClientFactory.stripe_client
      assert_instance_of Stubs::StripeClientStub, client
    end
  end

  def test_http_client_returns_stub_in_test_environment
    simulate_test_environment do
      client = ApiClientFactory.http_client
      assert_instance_of Stubs::HttpClientStub, client
    end
  end

  def test_stub_mode_returns_true_in_test_environment
    simulate_test_environment do
      assert ApiClientFactory.stub_mode?
    end
  end

  def test_stub_mode_returns_false_in_development_environment
    simulate_development_environment do
      refute ApiClientFactory.stub_mode?
    end
  end

  private

  def simulate_test_environment
    setup_mock_rails('test')
    yield
  end

  def simulate_development_environment
    setup_mock_rails('development')
    yield
  end

  def setup_mock_rails(environment)
    rails_mock = Minitest::Mock.new
    env_mock = Minitest::Mock.new
    
    env_mock.expect(:test?, environment == 'test')
    rails_mock.expect(:env, env_mock)
    
    Object.const_set(:Rails, rails_mock) unless defined?(Rails)
    
    # Reset Rails.env for the new environment if Rails was already defined
    if defined?(Rails) && Rails.respond_to(:env=)
      Rails.env = environment
    end
  end
end