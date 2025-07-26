# frozen_string_literal: true

# Mock configurations for external services to ensure tests run offline
RSpec.configure do |config|
  config.before(:each) do
    # Mock OpenAI API
    allow_any_instance_of(OpenAI::Client).to receive(:completions) do |args|
      {
        'choices' => [
          {
            'text' => 'Mocked OpenAI response',
            'finish_reason' => 'stop'
          }
        ]
      }
    end

    # Mock Anthropic/Claude API
    stub_request(:post, /api\.anthropic\.com/)
      .to_return(
        status: 200,
        body: {
          content: [{ text: 'Mocked Claude response' }],
          stop_reason: 'end_turn'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock Stripe API
    allow(Stripe::Customer).to receive(:create).and_return(
      double('customer', id: 'cus_test123', email: 'test@example.com')
    )
    allow(Stripe::Subscription).to receive(:create).and_return(
      double('subscription', id: 'sub_test123', status: 'active')
    )

    # Mock GitHub API
    stub_request(:get, /api\.github\.com/)
      .to_return(
        status: 200,
        body: { login: 'testuser', name: 'Test User' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock HTTP requests for MCP fetchers
    stub_request(:any, /example\.com/).to_return(
      status: 200,
      body: { data: 'mocked response' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end