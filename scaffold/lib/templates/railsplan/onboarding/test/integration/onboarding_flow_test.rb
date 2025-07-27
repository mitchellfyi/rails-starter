# frozen_string_literal: true

require 'test_helper'

class OnboardingFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "complete onboarding flow with all available modules" do
    # Start onboarding
    @user.start_onboarding!
    
    # Visit onboarding index
    get onboarding_path
    assert_redirected_to onboarding_step_path(@user.onboarding_progress.next_step)
    
    # Complete welcome step
    get onboarding_step_path('welcome')
    assert_response :success
    
    post onboarding_step_path('welcome')
    assert @user.onboarding_progress.reload.completed_step?('welcome')
    
    # Test workspace creation if available
    if ModuleDetector.new.workspace_module_available?
      get onboarding_step_path('create_workspace')
      assert_response :success
      
      post onboarding_step_path('create_workspace'), params: {
        workspace: {
          name: "Integration Test Workspace",
          description: "Created during integration test"
        }
      }
      assert @user.onboarding_progress.reload.completed_step?('create_workspace')
      
      # Test invitations if workspace was created
      get onboarding_step_path('invite_colleagues')
      assert_response :success
      
      post onboarding_step_path('invite_colleagues'), params: {
        workspace_id: @user.created_workspaces.first&.id,
        invitations: [
          { email: "test1@example.com", role: "member" },
          { email: "test2@example.com", role: "admin" }
        ]
      }
      assert @user.onboarding_progress.reload.completed_step?('invite_colleagues')
    end
    
    # Test billing if available
    if ModuleDetector.new.billing_module_available?
      get onboarding_step_path('connect_billing')
      assert_response :success
      
      post onboarding_step_path('connect_billing'), params: {
        billing: { plan: "trial" }
      }
      assert @user.onboarding_progress.reload.completed_step?('connect_billing')
    end
    
    # Test AI if available
    if ModuleDetector.new.ai_module_available?
      get onboarding_step_path('connect_ai')
      assert_response :success
      
      post onboarding_step_path('connect_ai'), params: {
        ai: { provider: "skip" }
      }
      assert @user.onboarding_progress.reload.completed_step?('connect_ai')
    end
    
    # Test explore features (always available)
    get onboarding_step_path('explore_features')
    assert_response :success
    
    post onboarding_step_path('explore_features')
    assert @user.onboarding_progress.reload.completed_step?('explore_features')
    
    # Should now be complete
    assert @user.onboarding_progress.reload.complete?
    
    # Visit complete step
    get onboarding_step_path('complete')
    assert_response :success
    assert_select 'h2', text: /Setup Complete/
  end

  test "skip onboarding flow" do
    # Start onboarding
    @user.start_onboarding!
    
    # Visit welcome step
    get onboarding_step_path('welcome')
    assert_response :success
    
    # Skip onboarding
    post skip_onboarding_path
    
    assert @user.onboarding_progress.reload.skipped?
    assert_redirected_to root_path
    assert_match /skipped/, flash[:notice]
  end

  test "resume onboarding after skipping" do
    # Skip onboarding first
    @user.start_onboarding!
    @user.skip_onboarding!
    
    # Resume onboarding
    post resume_onboarding_path
    
    assert_not @user.onboarding_progress.reload.skipped?
    assert_redirected_to onboarding_path
    assert_match /continue/, flash[:notice]
  end

  test "onboarding redirects when complete" do
    # Complete onboarding
    @user.start_onboarding!
    @user.complete_onboarding!
    
    # Try to visit onboarding
    get onboarding_path
    assert_redirected_to root_path
    assert_match /already completed/, flash[:notice]
  end

  test "progress indicator updates correctly" do
    @user.start_onboarding!
    
    # Initial progress should be 0%
    get onboarding_step_path('welcome')
    assert_response :success
    
    initial_progress = @user.onboarding_progress.progress_percentage
    assert_equal 0, initial_progress
    
    # Complete welcome step
    post onboarding_step_path('welcome')
    
    # Progress should increase
    updated_progress = @user.onboarding_progress.reload.progress_percentage
    assert updated_progress > initial_progress
  end

  test "handles invalid step gracefully" do
    @user.start_onboarding!
    
    get onboarding_step_path('invalid_step')
    assert_redirected_to onboarding_path
    assert_match /not available/, flash[:alert]
  end

  test "requires authentication for all onboarding actions" do
    sign_out @user
    
    # Test all onboarding routes require authentication
    get onboarding_path
    assert_redirected_to new_user_session_path
    
    get onboarding_step_path('welcome')
    assert_redirected_to new_user_session_path
    
    post onboarding_step_path('welcome')
    assert_redirected_to new_user_session_path
    
    post skip_onboarding_path
    assert_redirected_to new_user_session_path
    
    post resume_onboarding_path
    assert_redirected_to new_user_session_path
  end

  test "onboarding adapts to available modules" do
    @user.start_onboarding!
    detector = ModuleDetector.new
    
    # Welcome should always be available
    get onboarding_step_path('welcome')
    assert_response :success
    
    # Workspace steps should only be available if workspace module is present
    if detector.workspace_module_available?
      get onboarding_step_path('create_workspace')
      assert_response :success
      
      get onboarding_step_path('invite_colleagues')
      assert_response :success
    else
      get onboarding_step_path('create_workspace')
      assert_redirected_to onboarding_path
      
      get onboarding_step_path('invite_colleagues')
      assert_redirected_to onboarding_path
    end
    
    # Billing step should only be available if billing module is present
    if detector.billing_module_available?
      get onboarding_step_path('connect_billing')
      assert_response :success
    else
      get onboarding_step_path('connect_billing')
      assert_redirected_to onboarding_path
    end
    
    # AI step should only be available if AI module is present
    if detector.ai_module_available?
      get onboarding_step_path('connect_ai')
      assert_response :success
    else
      get onboarding_step_path('connect_ai')
      assert_redirected_to onboarding_path
    end
    
    # Explore features should always be available
    get onboarding_step_path('explore_features')
    assert_response :success
  end

  private

  def sign_in(user)
    # Mock sign in method - adjust based on your authentication system
    session[:user_id] = user.id if respond_to?(:session)
  end

  def sign_out(user)
    # Mock sign out method - adjust based on your authentication system
    session[:user_id] = nil if respond_to?(:session)
  end
end