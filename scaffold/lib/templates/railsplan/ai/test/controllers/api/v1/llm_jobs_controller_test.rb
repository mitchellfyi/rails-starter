# frozen_string_literal: true

require 'test_helper'

class Api::V1::LLMJobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # Assumes fixtures exist
    sign_in @user # Assumes Devise test helpers
    @valid_params = {
      template: "Hello {{name}}, tell me about {{topic}}",
      model: "gpt-4",
      context: { name: "Alice", topic: "Ruby" },
      format: "text"
    }
  end

  test "should create LLM job with valid parameters" do
    assert_difference 'LLMOutput.count', 1 do
      assert_enqueued_with(job: LLMJob) do
        post api_v1_llm_jobs_url, 
             params: @valid_params,
             headers: { 'Accept' => 'application/json' }
      end
    end

    assert_response :created
    response_json = JSON.parse(response.body)
    
    assert_includes response_json, 'job_id'
    assert_includes response_json, 'output_id'
    assert_equal 'queued', response_json['status']
    assert_includes response_json, 'estimated_completion'

    # Verify LLMOutput was created
    output = LLMOutput.find(response_json['output_id'])
    assert_equal @valid_params[:template], output.template_name
    assert_equal @valid_params[:model], output.model_name
    assert_equal @valid_params[:context].stringify_keys, output.context
    assert_equal @valid_params[:format], output.format
    assert_equal @user.id, output.user_id
    assert_equal 'pending', output.status
  end

  test "should create job with minimal parameters" do
    minimal_params = {
      template: "Simple template",
      model: "gpt-3.5"
    }

    assert_difference 'LLMOutput.count', 1 do
      post api_v1_llm_jobs_url,
           params: minimal_params,
           headers: { 'Accept' => 'application/json' }
    end

    assert_response :created
    
    output = LLMOutput.last
    assert_equal minimal_params[:template], output.template_name
    assert_equal minimal_params[:model], output.model_name
    assert_equal({}, output.context)
    assert_equal 'text', output.format # default format
  end

  test "should require template parameter" do
    invalid_params = @valid_params.except(:template)

    post api_v1_llm_jobs_url,
         params: invalid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert_includes response_json['error'], 'template'
  end

  test "should require model parameter" do
    invalid_params = @valid_params.except(:model)

    post api_v1_llm_jobs_url,
         params: invalid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert_includes response_json['error'], 'model'
  end

  test "should validate format parameter" do
    invalid_params = @valid_params.merge(format: 'invalid_format')

    post api_v1_llm_jobs_url,
         params: invalid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert_includes response_json['error'], 'Invalid format'
  end

  test "should accept valid format parameters" do
    %w[text json markdown html].each do |format|
      params = @valid_params.merge(format: format)

      assert_difference 'LLMOutput.count', 1 do
        post api_v1_llm_jobs_url,
             params: params,
             headers: { 'Accept' => 'application/json' }
      end

      assert_response :created, "#{format} should be a valid format"
      
      output = LLMOutput.last
      assert_equal format, output.format
    end
  end

  test "should validate context is a hash" do
    invalid_params = @valid_params.merge(context: "not a hash")

    post api_v1_llm_jobs_url,
         params: invalid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert_includes response_json['error'], 'Context must be a hash'
  end

  test "should require authentication" do
    sign_out @user

    post api_v1_llm_jobs_url,
         params: @valid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :unauthorized
  end

  test "should handle server errors gracefully" do
    # Mock an error in LLMOutput creation
    LLMOutput.stubs(:create!).raises(StandardError, "Database error")

    post api_v1_llm_jobs_url,
         params: @valid_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :internal_server_error
    response_json = JSON.parse(response.body)
    assert_equal 'Failed to queue job', response_json['error']
  end

  test "should accept nested context parameters" do
    nested_context = {
      user: { name: "Alice", age: 30 },
      preferences: { theme: "dark", language: "en" }
    }
    params = @valid_params.merge(context: nested_context)

    post api_v1_llm_jobs_url,
         params: params,
         headers: { 'Accept' => 'application/json' }

    assert_response :created
    
    output = LLMOutput.last
    assert_equal nested_context.deep_stringify_keys, output.context
  end

  test "should handle empty context" do
    params = @valid_params.merge(context: {})

    assert_difference 'LLMOutput.count', 1 do
      post api_v1_llm_jobs_url,
           params: params,
           headers: { 'Accept' => 'application/json' }
    end

    assert_response :created
    
    output = LLMOutput.last
    assert_equal({}, output.context)
  end
end