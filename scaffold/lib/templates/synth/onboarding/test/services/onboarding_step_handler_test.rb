# frozen_string_literal: true

require 'test_helper'

class OnboardingStepHandlerTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @handler = OnboardingStepHandler.new(@user)
  end

  test "should handle welcome step" do
    @user.start_onboarding!
    
    result = @handler.handle_step('welcome')
    assert result
    assert @user.onboarding_progress.reload.completed_step?('welcome')
  end

  test "should determine step availability correctly" do
    assert @handler.step_available?('welcome')
    assert @handler.step_available?('explore_features')
    
    # These depend on module availability
    workspace_available = @handler.step_available?('create_workspace')
    assert_equal ModuleDetector.new.workspace_module_available?, workspace_available
    
    billing_available = @handler.step_available?('connect_billing')
    assert_equal ModuleDetector.new.billing_module_available?, billing_available
    
    ai_available = @handler.step_available?('connect_ai')
    assert_equal ModuleDetector.new.ai_module_available?, ai_available
  end

  test "should not handle unavailable steps" do
    assert_not @handler.step_available?('invalid_step')
  end

  test "should provide step data" do
    welcome_data = @handler.get_step_data('welcome')
    
    assert welcome_data.is_a?(Hash)
    assert welcome_data[:title].present?
    assert welcome_data[:description].present?
    assert welcome_data[:available_modules].is_a?(Array)
  end

  test "should handle workspace creation with valid params" do
    @user.start_onboarding!
    
    # Skip test if workspace module not available
    unless ModuleDetector.new.workspace_module_available?
      skip "Workspace module not available"
    end
    
    params = {
      workspace: {
        name: "Test Workspace",
        description: "Test Description"
      }
    }
    
    result = @handler.handle_step('create_workspace', params)
    assert result
    assert @user.onboarding_progress.reload.completed_step?('create_workspace')
  end

  test "should handle workspace creation without params" do
    @user.start_onboarding!
    
    # Skip test if workspace module not available
    unless ModuleDetector.new.workspace_module_available?
      skip "Workspace module not available"
    end
    
    result = @handler.handle_step('create_workspace', {})
    assert_not result  # Should return false when no params provided
  end

  test "should handle invite colleagues step" do
    @user.start_onboarding!
    
    # Skip test if workspace module not available
    unless ModuleDetector.new.workspace_module_available?
      skip "Workspace module not available"
    end
    
    # Should mark as complete even without invitations (user can skip)
    result = @handler.handle_step('invite_colleagues', {})
    assert result
    assert @user.onboarding_progress.reload.completed_step?('invite_colleagues')
  end

  test "should handle billing step" do
    @user.start_onboarding!
    
    # Skip test if billing module not available
    unless ModuleDetector.new.billing_module_available?
      skip "Billing module not available"
    end
    
    result = @handler.handle_step('connect_billing', {})
    assert result
    assert @user.onboarding_progress.reload.completed_step?('connect_billing')
  end

  test "should handle ai step" do
    @user.start_onboarding!
    
    # Skip test if ai module not available
    unless ModuleDetector.new.ai_module_available?
      skip "AI module not available"
    end
    
    result = @handler.handle_step('connect_ai', {})
    assert result
    assert @user.onboarding_progress.reload.completed_step?('connect_ai')
  end

  test "should handle explore features step" do
    @user.start_onboarding!
    
    result = @handler.handle_step('explore_features')
    assert result
    assert @user.onboarding_progress.reload.completed_step?('explore_features')
  end

  test "should return false for invalid step" do
    @user.start_onboarding!
    
    result = @handler.handle_step('invalid_step')
    assert_not result
  end

  test "should provide complete step data" do
    @user.start_onboarding!
    @user.complete_onboarding!
    
    complete_data = @handler.get_step_data('complete')
    
    assert complete_data.is_a?(Hash)
    assert complete_data[:title].present?
    assert complete_data[:description].present?
    assert complete_data[:completed_steps].is_a?(Array)
  end
end