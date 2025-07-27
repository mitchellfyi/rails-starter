# frozen_string_literal: true

require 'test_helper'

class Api::V1::AiUsageEstimatorControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
    sign_in @user
    
    @headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  test "should estimate single usage via API" do
    data = {
      data: {
        type: 'ai_usage_estimation',
        attributes: {
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "John" },
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'ai_usage_estimation', json_response['data']['type']
    
    attributes = json_response['data']['attributes']
    assert_includes attributes.keys, 'prompt'
    assert_includes attributes.keys, 'total_cost'
    assert_includes attributes.keys, 'total_tokens'
    assert_includes attributes.keys, 'input_tokens'
    assert_includes attributes.keys, 'output_tokens'
    assert_includes attributes.keys, 'model'
    assert_includes attributes.keys, 'provider'
    
    assert_equal "Hello John", attributes['prompt']
    assert_equal "gpt-3.5-turbo", attributes['model']
    assert attributes['total_cost'] > 0
  end

  test "should validate required parameters for single estimation" do
    data = {
      data: {
        type: 'ai_usage_estimation',
        attributes: {
          # Missing template and model
          context: { name: "John" },
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Missing required parameter'
  end

  test "should validate format for single estimation" do
    data = {
      data: {
        type: 'ai_usage_estimation',
        attributes: {
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "John" },
          format: "invalid_format"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Invalid format'
  end

  test "should validate context is hash for single estimation" do
    data = {
      data: {
        type: 'ai_usage_estimation',
        attributes: {
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: "not a hash",
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Invalid context'
  end

  test "should estimate batch usage via API" do
    inputs = [
      { name: "John", message: "Hello" },
      { name: "Jane", message: "Hi there" }
    ]
    
    data = {
      data: {
        type: 'ai_batch_usage_estimation',
        attributes: {
          template: "Say {{message}} to {{name}}",
          model: "gpt-3.5-turbo",
          inputs: inputs,
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/batch_estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'ai_batch_usage_estimation', json_response['data']['type']
    
    attributes = json_response['data']['attributes']
    assert_includes attributes.keys, 'estimates'
    assert_includes attributes.keys, 'summary'
    
    assert_equal 2, attributes['estimates'].length
    assert_equal 2, attributes['summary']['total_inputs']
    assert_equal 2, attributes['summary']['successful_estimates']
    assert attributes['summary']['total_cost'] > 0
  end

  test "should validate inputs is array for batch estimation" do
    data = {
      data: {
        type: 'ai_batch_usage_estimation',
        attributes: {
          template: "Say {{message}} to {{name}}",
          model: "gpt-3.5-turbo",
          inputs: "not an array",
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/batch_estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Invalid inputs'
  end

  test "should validate each input is hash for batch estimation" do
    inputs = [
      { name: "John", message: "Hello" },
      "not a hash"  # Invalid input
    ]
    
    data = {
      data: {
        type: 'ai_batch_usage_estimation',
        attributes: {
          template: "Say {{message}} to {{name}}",
          model: "gpt-3.5-turbo",
          inputs: inputs,
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/batch_estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Invalid input'
    assert_includes json_response['errors'][0]['source']['pointer'], '/data/attributes/inputs/1'
  end

  test "should enforce batch size limit via API" do
    large_inputs = (1..1001).map { |i| { name: "User#{i}", message: "Hello" } }
    
    data = {
      data: {
        type: 'ai_batch_usage_estimation',
        attributes: {
          template: "Say {{message}} to {{name}}",
          model: "gpt-3.5-turbo",
          inputs: large_inputs,
          format: "text"
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/batch_estimate', 
         params: data.to_json,
         headers: @headers
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['errors'][0]['title'], 'Batch size too large'
  end

  test "should get available models via API" do
    get '/api/v1/ai_usage_estimator/models', headers: @headers
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'ai_models', json_response['data']['type']
    
    attributes = json_response['data']['attributes']
    assert_includes attributes.keys, 'models'
    
    models = attributes['models']
    assert models.is_a?(Array)
    assert models.length > 0
    
    # Check structure of first model
    first_model = models.first
    assert_includes first_model.keys, 'model'
    assert_includes first_model.keys, 'provider'
    assert_includes first_model.keys, 'pricing_per_1k_tokens'
    
    pricing = first_model['pricing_per_1k_tokens']
    assert_includes pricing.keys, 'input'
    assert_includes pricing.keys, 'output'
    assert pricing['input'] > 0
    assert pricing['output'] > 0
  end

  test "should handle API errors gracefully" do
    # Test with malformed JSON
    post '/api/v1/ai_usage_estimator/estimate', 
         params: 'invalid json',
         headers: @headers
    
    assert_response :bad_request
  end

  test "should work with ai_credential_id parameter" do
    # This test would need actual AI credential setup in a real scenario
    data = {
      data: {
        type: 'ai_usage_estimation',
        attributes: {
          template: "Hello {{name}}",
          model: "gpt-3.5-turbo",
          context: { name: "John" },
          format: "text",
          ai_credential_id: "nonexistent-id"  # Would be invalid but shouldn't crash
        }
      }
    }
    
    post '/api/v1/ai_usage_estimator/estimate', 
         params: data.to_json,
         headers: @headers
    
    # Should still work even with invalid credential ID (falls back to default pricing)
    assert_response :success
  end
end