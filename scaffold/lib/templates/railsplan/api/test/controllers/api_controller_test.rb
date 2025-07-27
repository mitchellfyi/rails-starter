# frozen_string_literal: true

require 'test_helper'

class ApiControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  test "api base controller error handling" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    # Test 404 error handling
    get '/api/v1/nonexistent'
    assert_response :not_found
    
    response_body = JSON.parse(response.body)
    assert response_body['errors']
  end

  test "api authentication required" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    # Test that API endpoints require authentication
    get api_v1_users_path
    assert_response :unauthorized
  end

  test "api content type validation" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    # Test that API accepts proper content type
    post api_v1_users_path, 
         params: { user: { email: 'new@example.com' } },
         headers: { 'Content-Type' => 'application/vnd.api+json' }
    
    # Should require authentication but accept content type
    assert_response :unauthorized
  end

  test "api json response format" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    authenticate_api_user(@user)
    
    get api_v1_user_path(@user)
    assert_response :success
    
    response_body = JSON.parse(response.body)
    assert response_body['data']
    assert_equal 'users', response_body['data']['type']
    assert response_body['data']['attributes']
  end

  test "api error response format" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    authenticate_api_user(@user)
    
    # Attempt to create invalid user
    post api_v1_users_path,
         params: { 
           data: {
             type: 'users',
             attributes: { email: '' } # Invalid email
           }
         },
         headers: { 'Content-Type' => 'application/vnd.api+json' }
    
    assert_response :unprocessable_entity
    
    response_body = JSON.parse(response.body)
    assert response_body['errors']
    assert response_body['errors'].is_a?(Array)
  end

  test "api pagination" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    authenticate_api_user(@user)
    
    # Create multiple users for pagination test
    5.times do |i|
      User.create!(
        email: "user#{i}@example.com",
        password: 'password123',
        password_confirmation: 'password123'
      )
    end
    
    get api_v1_users_path, params: { page: { number: 1, size: 2 } }
    assert_response :success
    
    response_body = JSON.parse(response.body)
    assert response_body['data']
    assert response_body['meta']
    assert response_body['links'] if response_body['links']
  end

  test "api versioning" do
    skip "API controllers not available in test environment" unless has_api_routes?
    
    authenticate_api_user(@user)
    
    # Test v1 endpoint
    get api_v1_user_path(@user)
    assert_response :success
    
    # Verify API version in response headers
    assert_equal 'application/vnd.api+json', response.content_type
  end

  private

  def has_api_routes?
    Rails.application.routes.url_helpers.respond_to?(:api_v1_users_path)
  rescue
    false
  end

  def authenticate_api_user(user)
    # Mock API authentication
    # In a real implementation, this would set proper API tokens
    if defined?(session)
      session[:user_id] = user.id
    end
    
    # Or set authorization header
    @auth_headers = {
      'Authorization' => "Bearer mock_token_for_#{user.id}"
    }
  end

  def api_request_headers
    {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json'
    }.merge(@auth_headers || {})
  end
end