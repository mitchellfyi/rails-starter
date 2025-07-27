# frozen_string_literal: true

require 'test_helper'

class AiCredentialsControllerTest < ActionController::TestCase
  setup do
    @user = User.create!(email: "admin@example.com", password: "password")
    @workspace = Workspace.create!(
      name: "Test Workspace",
      slug: "test-workspace",
      created_by: @user
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    @ai_credential = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "Test Credential",
      api_key: "test-key",
      preferred_model: "gpt-4"
    )
    
    sign_in @user
    @request.env["HTTP_REFERER"] = "/workspaces/#{@workspace.slug}"
  end

  test "should get index" do
    get :index, params: { workspace_slug: @workspace.slug }
    assert_response :success
    assert_includes assigns(:ai_credentials), @ai_credential
  end

  test "should show ai_credential" do
    get :show, params: { workspace_slug: @workspace.slug, id: @ai_credential.id }
    assert_response :success
    assert_equal @ai_credential, assigns(:ai_credential)
  end

  test "should get new" do
    get :new, params: { workspace_slug: @workspace.slug }
    assert_response :success
    assert assigns(:ai_credential).new_record?
  end

  test "should create ai_credential" do
    assert_difference 'AiCredential.count' do
      post :create, params: {
        workspace_slug: @workspace.slug,
        ai_credential: {
          ai_provider_id: @ai_provider.id,
          name: "New Credential",
          api_key: "new-test-key",
          preferred_model: "gpt-3.5-turbo"
        }
      }
    end
    
    assert_redirected_to [@workspace, assigns(:ai_credential)]
    assert_equal "New Credential", assigns(:ai_credential).name
  end

  test "should get edit" do
    get :edit, params: { workspace_slug: @workspace.slug, id: @ai_credential.id }
    assert_response :success
    assert_equal @ai_credential, assigns(:ai_credential)
  end

  test "should update ai_credential" do
    patch :update, params: {
      workspace_slug: @workspace.slug,
      id: @ai_credential.id,
      ai_credential: { name: "Updated Name" }
    }
    
    assert_redirected_to [@workspace, @ai_credential]
    @ai_credential.reload
    assert_equal "Updated Name", @ai_credential.name
  end

  test "should destroy ai_credential" do
    assert_difference 'AiCredential.count', -1 do
      delete :destroy, params: { workspace_slug: @workspace.slug, id: @ai_credential.id }
    end
    
    assert_redirected_to [@workspace, :ai_credentials]
  end

  test "should test connection" do
    # Mock the test service to avoid actual API calls
    mock_service = Minitest::Mock.new
    mock_service.expect :test_connection, { success: true, message: "Test successful" }
    
    AiProviderTestService.stub :new, mock_service do
      post :test_connection, params: { workspace_slug: @workspace.slug, id: @ai_credential.id }
    end
    
    assert_redirected_to [@workspace, @ai_credential]
    assert_equal "Connection test successful: Test successful", flash[:notice]
    mock_service.verify
  end

  test "should handle failed connection test" do
    # Mock the test service to return failure
    mock_service = Minitest::Mock.new
    mock_service.expect :test_connection, { success: false, error: "API key invalid" }
    
    AiProviderTestService.stub :new, mock_service do
      post :test_connection, params: { workspace_slug: @workspace.slug, id: @ai_credential.id }
    end
    
    assert_redirected_to [@workspace, @ai_credential]
    assert_equal "Connection test failed: API key invalid", flash[:alert]
    mock_service.verify
  end

  test "should require workspace admin access" do
    # Create a non-admin user
    non_admin = User.create!(email: "user@example.com", password: "password")
    sign_in non_admin
    
    get :index, params: { workspace_slug: @workspace.slug }
    assert_redirected_to root_path
    assert_equal "Access denied. Workspace admin privileges required.", flash[:alert]
  end

  private

  def sign_in(user)
    # This would be replaced with your actual authentication method
    session[:user_id] = user.id
    @controller.stubs(:current_user).returns(user)
    @controller.stubs(:authenticate_user!).returns(true)
  end
end