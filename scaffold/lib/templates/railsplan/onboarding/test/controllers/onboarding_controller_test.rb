# frozen_string_literal: true

require 'test_helper'

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "should redirect to current step from index" do
    @user.start_onboarding!
    
    get onboarding_path
    assert_redirected_to onboarding_step_path(@user.onboarding_progress.next_step)
  end

  test "should redirect to root if onboarding complete" do
    @user.start_onboarding!
    @user.complete_onboarding!
    
    get onboarding_path
    assert_redirected_to root_path
    assert_match /already completed/, flash[:notice]
  end

  test "should show welcome step" do
    @user.start_onboarding!
    
    get onboarding_step_path('welcome')
    assert_response :success
    assert_select 'h2', text: /Welcome/
  end

  test "should not show unavailable step" do
    @user.start_onboarding!
    
    get onboarding_step_path('invalid_step')
    assert_redirected_to onboarding_path
    assert_match /not available/, flash[:alert]
  end

  test "should complete welcome step" do
    @user.start_onboarding!
    
    post onboarding_step_path('welcome')
    
    assert @user.onboarding_progress.reload.completed_step?('welcome')
    assert_redirected_to onboarding_step_path(@user.onboarding_progress.next_step)
  end

  test "should handle workspace creation step" do
    @user.start_onboarding!
    
    # Skip if workspace module not available
    unless ModuleDetector.new.workspace_module_available?
      skip "Workspace module not available"
    end
    
    workspace_params = {
      workspace: {
        name: "Test Workspace",
        description: "A test workspace"
      }
    }
    
    post onboarding_step_path('create_workspace'), params: workspace_params
    
    assert @user.onboarding_progress.reload.completed_step?('create_workspace')
  end

  test "should skip onboarding" do
    @user.start_onboarding!
    
    post skip_onboarding_path
    
    assert @user.onboarding_progress.reload.skipped?
    assert_redirected_to root_path
    assert_match /skipped/, flash[:notice]
  end

  test "should resume onboarding" do
    @user.skip_onboarding!
    
    post resume_onboarding_path
    
    assert_not @user.onboarding_progress.reload.skipped?
    assert_redirected_to onboarding_path
    assert_match /continue/, flash[:notice]
  end

  test "should require authentication" do
    sign_out @user
    
    get onboarding_path
    assert_redirected_to new_user_session_path
  end

  test "should handle step completion with invalid data" do
    @user.start_onboarding!
    
    post onboarding_step_path('welcome'), params: { invalid: 'data' }
    
    # Should still work for welcome step as it doesn't require data
    assert @user.onboarding_progress.reload.completed_step?('welcome')
  end

  test "should show complete step when all steps done" do
    @user.start_onboarding!
    @user.complete_onboarding!
    
    get onboarding_step_path('complete')
    assert_response :success
    assert_select 'h2', text: /Setup Complete/
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