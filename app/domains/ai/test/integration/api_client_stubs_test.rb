# frozen_string_literal: true

require 'test_helper'
require_relative '../../../lib/api_client_factory'

class ApiClientStubsIntegrationTest < ActiveSupport::TestCase
  setup do
    # Ensure we're in test mode for these tests
    Rails.env.stubs(:test?).returns(true)
    
    # Clear any cached clients
    ApiClientFactory.instance_variables.each do |var|
      ApiClientFactory.remove_instance_variable(var) if ApiClientFactory.instance_variable_defined?(var)
    end
  end

  test "api client factory returns stub clients in test environment" do
    assert ApiClientFactory.stub_mode?
    
    openai_client = ApiClientFactory.openai_client
    assert_instance_of Stubs::OpenAIClientStub, openai_client
    
    github_client = ApiClientFactory.github_client
    assert_instance_of Stubs::GitHubClientStub, github_client
    
    stripe_client = ApiClientFactory.stripe_client
    assert_instance_of Stubs::StripeClientStub, stripe_client
    
    http_client = ApiClientFactory.http_client
    assert_instance_of Stubs::HttpClientStub, http_client
  end

  test "openai stub returns deterministic responses" do
    client = ApiClientFactory.openai_client
    
    # Same input should produce same response
    messages = [{ role: 'user', content: 'Hello, world!' }]
    response1 = client.completions(model: 'gpt-4', messages: messages)
    response2 = client.completions(model: 'gpt-4', messages: messages)
    
    assert_equal response1['choices'][0]['message']['content'],
                 response2['choices'][0]['message']['content']
    
    # Different input should produce different response
    different_messages = [{ role: 'user', content: 'Goodbye, world!' }]
    response3 = client.completions(model: 'gpt-4', messages: different_messages)
    
    refute_equal response1['choices'][0]['message']['content'],
                 response3['choices'][0]['message']['content']
  end

  test "openai stub handles different formats correctly" do
    client = ApiClientFactory.openai_client
    
    # JSON format
    json_messages = [{ role: 'user', content: 'Return JSON data' }]
    json_response = client.completions(messages: json_messages)
    json_content = json_response['choices'][0]['message']['content']
    
    assert json_content.start_with?('{')
    assert_includes json_content.downcase, 'json'
    
    # Markdown format
    md_messages = [{ role: 'user', content: 'Return markdown format' }]
    md_response = client.completions(messages: md_messages)
    md_content = md_response['choices'][0]['message']['content']
    
    assert md_content.start_with?('# ')
    assert_includes md_content.downcase, 'markdown'
  end

  test "github stub returns realistic user data" do
    client = ApiClientFactory.github_client
    
    user = client.user('octocat')
    
    assert_equal 'octocat', user['login']
    assert user['id'].is_a?(Integer)
    assert user['public_repos'].is_a?(Integer)
    assert user['followers'].is_a?(Integer)
    assert_equal 'User', user['type']
    assert_includes user.keys, 'created_at'
    assert_includes user.keys, 'updated_at'
  end

  test "github stub returns deterministic repository data" do
    client = ApiClientFactory.github_client
    
    repos1 = client.repos('testuser', per_page: 5)
    repos2 = client.repos('testuser', per_page: 5)
    
    # Same request should produce same data
    assert_equal repos1, repos2
    assert repos1.length <= 5
    
    repos1.each do |repo|
      assert repo['name'].is_a?(String)
      assert repo['full_name'].start_with?('testuser')
      assert repo['stargazers_count'].is_a?(Integer)
      assert repo['language'].is_a?(String)
      assert_includes [true, false], repo['private']
    end
  end

  test "stripe stub creates realistic customer data" do
    client = ApiClientFactory.stripe_client
    
    customer = client.customer.create(
      email: 'test@example.com',
      name: 'Test Customer'
    )
    
    assert customer['id'].start_with?('cus_')
    assert_equal 'customer', customer['object']
    assert_equal 'test@example.com', customer['email']
    assert_equal 'Test Customer', customer['name']
    assert customer['created'].is_a?(Integer)
  end

  test "stripe stub creates subscription with proper structure" do
    client = ApiClientFactory.stripe_client
    
    subscription = client.subscription.create(
      customer: 'cus_test123',
      items: [{ price: 'price_test123' }]
    )
    
    assert subscription['id'].start_with?('sub_')
    assert_equal 'subscription', subscription['object']
    assert_equal 'cus_test123', subscription['customer']
    assert_includes ['active', 'trialing'], subscription['status']
    assert subscription['items']['data'].is_a?(Array)
    assert subscription['items']['data'].length > 0
  end

  test "http stub returns deterministic responses" do
    client = ApiClientFactory.http_client
    
    # Test GitHub API endpoint
    response = client.get('https://api.github.com/users/octocat')
    
    assert_equal 200, response[:status]
    assert response[:success]
    assert response[:data]['login']
    assert response[:data]['id'].is_a?(Integer)
    
    # Same request should produce same response
    response2 = client.get('https://api.github.com/users/octocat')
    assert_equal response[:data], response2[:data]
  end

  test "http stub tracks request history" do
    client = ApiClientFactory.http_client
    
    client.clear_mocks
    
    client.get('https://api.example.com/test')
    client.post('https://api.example.com/create', body: 'test data')
    
    assert_equal 2, client.request_log.length
    assert client.requested?('https://api.example.com/test', method: :get)
    assert client.requested?('https://api.example.com/create', method: :post)
    assert_equal 1, client.request_count('test', method: :get)
  end

  test "llm job uses stub client in test environment" do
    # This test verifies that LLMJob actually uses our stub client
    user = users(:one) # Assumes fixtures exist
    
    # Verify the job uses deterministic responses
    output1 = LLMJob.perform_now(
      template: "Say {{message}}",
      model: "gpt-4",
      context: { message: "hello" },
      format: "text",
      user_id: user.id
    )
    
    output2 = LLMJob.perform_now(
      template: "Say {{message}}",
      model: "gpt-4",
      context: { message: "hello" },
      format: "text",
      user_id: user.id
    )
    
    # Same inputs should produce same outputs
    assert_equal output1.raw_response, output2.raw_response
    
    # Response should be from our stub (contains "deterministic" or similar patterns)
    assert output1.raw_response.length > 0
    # The stub includes model name and deterministic patterns in responses
    assert_includes output1.raw_response.downcase, 'gpt-4'
  end

  test "mcp github fetcher uses stub in test environment" do
    # Test that MCP GitHub fetcher uses our stub
    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: 'testuser',
      include_repos: true,
      repo_limit: 3
    )
    
    assert result[:success]
    assert_equal 'testuser', result[:username]
    assert result[:profile].present?
    assert result[:repositories].present?
    assert_equal 3, result[:repositories][:count]
    
    # Data should be deterministic
    result2 = Mcp::Fetcher::GitHubInfo.fetch(
      username: 'testuser',
      include_repos: true,
      repo_limit: 3
    )
    
    assert_equal result[:repositories][:repositories], 
                 result2[:repositories][:repositories]
  end

  test "error simulation works for all stub clients" do
    openai_client = ApiClientFactory.openai_client
    github_client = ApiClientFactory.github_client
    stripe_client = ApiClientFactory.stripe_client
    http_client = ApiClientFactory.http_client
    
    # Test that all clients can simulate errors
    assert_raises(StandardError) { openai_client.simulate_error(:rate_limit) }
    assert_raises(StandardError) { github_client.simulate_error(:not_found) }
    assert_raises(StandardError) { stripe_client.simulate_error(:card_declined) }
    assert_raises(StandardError) { http_client.simulate_error(:timeout) }
  end
end