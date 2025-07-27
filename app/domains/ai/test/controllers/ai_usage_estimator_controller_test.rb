# frozen_string_literal: true

require 'test_helper'

class AiUsageEstimatorControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
    sign_in @user
  end

  test "should get index" do
    get ai_usage_estimator_index_url
    assert_response :success
    assert_select 'h1', 'AI Usage Simulator & Planner'
  end

  test "should handle estimate with valid parameters" do
    post ai_usage_estimator_estimate_url, params: {
      template: "Hello {{name}}",
      model: "gpt-3.5-turbo",
      context: '{"name": "John"}',
      format: "text"
    }
    
    assert_response :success
    assert_select '.text-3xl.font-bold', text: /\$\d+\.\d+/  # Should show cost
  end

  test "should handle estimate with JSON response" do
    post ai_usage_estimator_estimate_url, 
         params: {
           template: "Hello {{name}}",
           model: "gpt-3.5-turbo",
           context: '{"name": "John"}',
           format: "text"
         },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, 'estimation'
    
    estimation = json_response['estimation']
    assert_includes estimation.keys, 'prompt'
    assert_includes estimation.keys, 'total_cost'
    assert_includes estimation.keys, 'total_tokens'
  end

  test "should reject invalid format" do
    post ai_usage_estimator_estimate_url,
         params: {
           template: "Hello {{name}}",
           model: "gpt-3.5-turbo",
           context: '{"name": "John"}',
           format: "invalid_format"
         },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_includes json_response['error'], 'Invalid format'
  end

  test "should reject malformed context JSON" do
    post ai_usage_estimator_estimate_url,
         params: {
           template: "Hello {{name}}",
           model: "gpt-3.5-turbo",
           context: 'invalid json',
           format: "text"
         },
         as: :json
    
    assert_response :internal_server_error
  end

  test "should handle missing required parameters" do
    post ai_usage_estimator_estimate_url,
         params: {
           # Missing template and model
           context: '{"name": "John"}',
           format: "text"
         },
         as: :json
    
    assert_response :bad_request
  end

  test "should handle batch estimate with manual input" do
    inputs_data = [
      { name: "John", message: "Hello" },
      { name: "Jane", message: "Hi there" }
    ]
    
    post ai_usage_estimator_batch_estimate_url, params: {
      template: "Say {{message}} to {{name}}",
      model: "gpt-3.5-turbo",
      inputs: inputs_data.to_json,
      format: "text"
    }
    
    assert_response :success
  end

  test "should handle batch estimate with JSON response" do
    inputs_data = [
      { name: "John", message: "Hello" },
      { name: "Jane", message: "Hi there" }
    ]
    
    post ai_usage_estimator_batch_estimate_url, 
         params: {
           template: "Say {{message}} to {{name}}",
           model: "gpt-3.5-turbo",
           inputs: inputs_data.to_json,
           format: "text"
         },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, 'batch_estimation'
    
    batch_estimation = json_response['batch_estimation']
    assert_includes batch_estimation.keys, 'estimates'
    assert_includes batch_estimation.keys, 'summary'
    
    assert_equal 2, batch_estimation['estimates'].length
    assert_equal 2, batch_estimation['summary']['total_inputs']
  end

  test "should handle batch estimate with empty inputs" do
    post ai_usage_estimator_batch_estimate_url,
         params: {
           template: "Say {{message}} to {{name}}",
           model: "gpt-3.5-turbo",
           inputs: "[]",
           format: "text"
         },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_includes json_response['error'], 'No valid inputs found'
  end

  test "should handle batch estimate with file upload" do
    # Create a temporary CSV file
    csv_content = "name,message\nJohn,Hello\nJane,Hi there"
    csv_file = Tempfile.new(['test', '.csv'])
    csv_file.write(csv_content)
    csv_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test.csv')
    
    post ai_usage_estimator_batch_estimate_url, params: {
      template: "Say {{message}} to {{name}}",
      model: "gpt-3.5-turbo",
      file: uploaded_file,
      format: "text"
    }
    
    assert_response :success
    
    csv_file.close
    csv_file.unlink
  end

  test "should handle batch estimate with JSON file upload" do
    # Create a temporary JSON file
    json_content = [
      { name: "John", message: "Hello" },
      { name: "Jane", message: "Hi there" }
    ].to_json
    
    json_file = Tempfile.new(['test', '.json'])
    json_file.write(json_content)
    json_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(json_file.path, 'application/json', original_filename: 'test.json')
    
    post ai_usage_estimator_batch_estimate_url, params: {
      template: "Say {{message}} to {{name}}",
      model: "gpt-3.5-turbo",
      file: uploaded_file,
      format: "text"
    }
    
    assert_response :success
    
    json_file.close
    json_file.unlink
  end

  test "should reject unsupported file format" do
    # Create a temporary text file (unsupported)
    txt_file = Tempfile.new(['test', '.txt'])
    txt_file.write("some content")
    txt_file.rewind
    
    uploaded_file = Rack::Test::UploadedFile.new(txt_file.path, 'text/plain', original_filename: 'test.txt')
    
    post ai_usage_estimator_batch_estimate_url,
         params: {
           template: "Say {{message}} to {{name}}",
           model: "gpt-3.5-turbo",
           file: uploaded_file,
           format: "text"
         },
         as: :json
    
    assert_response :internal_server_error
    json_response = JSON.parse(response.body)
    assert_includes json_response['details'], 'Unsupported file format'
    
    txt_file.close
    txt_file.unlink
  end

  test "should enforce batch size limit" do
    # Create inputs exceeding the limit
    large_inputs = (1..1001).map { |i| { name: "User#{i}", message: "Hello" } }
    
    post ai_usage_estimator_batch_estimate_url,
         params: {
           template: "Say {{message}} to {{name}}",
           model: "gpt-3.5-turbo",
           inputs: large_inputs.to_json,
           format: "text"
         },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_includes json_response['error'], 'Batch size too large'
  end

  private

  def ai_usage_estimator_index_url
    "/ai_usage_estimator"
  end

  def ai_usage_estimator_estimate_url
    "/ai_usage_estimator/estimate"
  end

  def ai_usage_estimator_batch_estimate_url
    "/ai_usage_estimator/batch_estimate"
  end
end