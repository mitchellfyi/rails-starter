# frozen_string_literal: true

require_relative '../../../../lib/stubs/openai_client_stub'
require 'minitest/autorun'

class OpenAIClientStubTest < Minitest::Test
  def setup
    @client = Stubs::OpenAIClientStub.new
  end

  def test_completions_returns_deterministic_response
    messages = [{ role: 'user', content: 'Hello, world!' }]
    
    response1 = @client.completions(model: 'gpt-4', messages: messages)
    response2 = @client.completions(model: 'gpt-4', messages: messages)
    
    # Same input should produce same response
    assert_equal response1['choices'][0]['message']['content'],
                 response2['choices'][0]['message']['content']
    
    # Response should contain expected structure
    assert_equal 'chat.completion', response1['object']
    assert_equal 'gpt-4', response1['model']
    assert_equal 'assistant', response1['choices'][0]['message']['role']
    refute_empty response1['choices'][0]['message']['content']
  end

  def test_completions_generates_different_responses_for_different_inputs
    messages1 = [{ role: 'user', content: 'Hello' }]
    messages2 = [{ role: 'user', content: 'Goodbye' }]
    
    response1 = @client.completions(messages: messages1)
    response2 = @client.completions(messages: messages2)
    
    # Different inputs should produce different responses
    refute_equal response1['choices'][0]['message']['content'],
                 response2['choices'][0]['message']['content']
  end

  def test_completions_handles_json_requests
    messages = [{ role: 'user', content: 'Return JSON data' }]
    
    response = @client.completions(messages: messages)
    content = response['choices'][0]['message']['content']
    
    # Should detect JSON request and return JSON-like response
    assert_includes content.downcase, 'json'
    assert content.start_with?('{')
  end

  def test_completions_handles_markdown_requests
    messages = [{ role: 'user', content: 'Return markdown format' }]
    
    response = @client.completions(messages: messages)
    content = response['choices'][0]['message']['content']
    
    # Should detect markdown request and return markdown response
    assert content.start_with?('# ')
    assert_includes content.downcase, 'markdown'
  end

  def test_completions_handles_code_requests
    messages = [{ role: 'user', content: 'Write some code' }]
    
    response = @client.completions(messages: messages)
    content = response['choices'][0]['message']['content']
    
    # Should detect code request and return code block
    assert_includes content, '```'
    assert_includes content.downcase, 'code'
  end

  def test_text_completions_legacy_api
    prompt = 'Once upon a time'
    
    response = @client.text_completions(prompt: prompt, model: 'text-davinci-003')
    
    assert_equal 'text_completion', response['object']
    assert_equal 'text-davinci-003', response['model']
    refute_empty response['choices'][0]['text']
  end

  def test_embeddings_returns_deterministic_vectors
    input = 'test embedding text'
    
    response1 = @client.embeddings(input: input)
    response2 = @client.embeddings(input: input)
    
    # Same input should produce same embedding
    assert_equal response1['data'][0]['embedding'], response2['data'][0]['embedding']
    
    # Should have correct structure
    assert_equal 'list', response1['object']
    assert_equal 1536, response1['data'][0]['embedding'].length
    assert response1['data'][0]['embedding'].all? { |val| val.is_a?(Float) }
  end

  def test_embeddings_generates_different_vectors_for_different_inputs
    response1 = @client.embeddings(input: 'first text')
    response2 = @client.embeddings(input: 'second text')
    
    # Different inputs should produce different embeddings
    refute_equal response1['data'][0]['embedding'], response2['data'][0]['embedding']
  end

  def test_models_returns_available_models
    response = @client.models
    
    assert_equal 'list', response['object']
    assert response['data'].is_a?(Array)
    assert response['data'].length > 0
    
    # Should include common models
    model_ids = response['data'].map { |model| model['id'] }
    assert_includes model_ids, 'gpt-4'
    assert_includes model_ids, 'gpt-3.5-turbo'
    assert_includes model_ids, 'text-embedding-ada-002'
  end

  def test_simulate_error_raises_appropriate_errors
    assert_raises(StandardError) { @client.simulate_error(:rate_limit) }
    assert_raises(StandardError) { @client.simulate_error(:invalid_api_key) }
    assert_raises(StandardError) { @client.simulate_error(:service_unavailable) }
  end

  def test_error_messages_are_descriptive
    begin
      @client.simulate_error(:rate_limit)
      flunk "Expected error to be raised"
    rescue StandardError => e
      assert_includes e.message.downcase, 'rate limit'
    end

    begin
      @client.simulate_error(:invalid_api_key)
      flunk "Expected error to be raised"
    rescue StandardError => e
      assert_includes e.message.downcase, 'api key'
    end
  end
end