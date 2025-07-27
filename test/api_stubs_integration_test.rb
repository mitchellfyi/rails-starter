# frozen_string_literal: true

# Test helper for API client stubs
require_relative '../lib/api_client_factory'

# Mock Rails environment for testing the factory
class MockRailsEnv
  def initialize(env_name)
    @env_name = env_name
  end

  def test?
    @env_name == 'test'
  end

  def development?
    @env_name == 'development'
  end

  def production?
    @env_name == 'production'
  end
end

class MockRails
  attr_accessor :env

  def initialize(env_name = 'test')
    @env = MockRailsEnv.new(env_name)
  end
end

# Set up test environment
unless defined?(Rails)
  Rails = MockRails.new('test')
end

# Test that API client factory works correctly
puts "Testing API Client Factory..."

# Test OpenAI client
openai_client = ApiClientFactory.openai_client
puts "✅ OpenAI client: #{openai_client.class}"

# Test GitHub client
github_client = ApiClientFactory.github_client
puts "✅ GitHub client: #{github_client.class}"

# Test Stripe client
stripe_client = ApiClientFactory.stripe_client
puts "✅ Stripe client: #{stripe_client.class}"

# Test HTTP client
http_client = ApiClientFactory.http_client
puts "✅ HTTP client: #{http_client.class}"

# Test stub mode detection
puts "✅ Stub mode: #{ApiClientFactory.stub_mode?}"

# Test basic functionality
puts "\nTesting basic functionality..."

# Test OpenAI
openai_response = openai_client.completions(
  messages: [{ role: 'user', content: 'Hello' }],
  model: 'gpt-4'
)
puts "✅ OpenAI response: #{openai_response['choices'][0]['message']['content'][0..50]}..."

# Test GitHub
github_user = github_client.user('testuser')
puts "✅ GitHub user: #{github_user['login']} (#{github_user['public_repos']} repos)"

# Test Stripe
stripe_customer = stripe_client.customer.create(email: 'test@example.com', name: 'Test User')
puts "✅ Stripe customer: #{stripe_customer['id']} (#{stripe_customer['email']})"

# Test HTTP
http_response = http_client.get('https://api.github.com/users/octocat')
puts "✅ HTTP response: #{http_response[:status]} - #{http_response[:data]['message'] || 'Success'}"

puts "\n🎉 All API client stubs are working correctly!"