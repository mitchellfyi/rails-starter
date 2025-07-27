# frozen_string_literal: true

require 'test_helper'

class OnboardingProgressTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @progress = OnboardingProgress.new(user: @user)
  end

  test "should be valid with valid attributes" do
    assert @progress.valid?
  end

  test "should require user" do
    @progress.user = nil
    assert_not @progress.valid?
    assert_includes @progress.errors[:user], "must exist"
  end

  test "should set defaults on create" do
    progress = OnboardingProgress.create!(user: @user)
    assert_equal 'welcome', progress.current_step
    assert_equal [], progress.completed_steps
    assert_not progress.skipped
  end

  test "should mark step as complete" do
    @progress.save!
    @progress.mark_step_complete('welcome')
    
    assert_includes @progress.completed_steps, 'welcome'
    assert @progress.completed_step?('welcome')
  end

  test "should not duplicate completed steps" do
    @progress.save!
    @progress.mark_step_complete('welcome')
    @progress.mark_step_complete('welcome')
    
    assert_equal 1, @progress.completed_steps.count('welcome')
  end

  test "should calculate progress percentage" do
    @progress.save!
    
    # With no modules, should have welcome, explore_features as available steps
    initial_percentage = @progress.progress_percentage
    assert_equal 0, initial_percentage
    
    @progress.mark_step_complete('welcome')
    
    # Should increase after completing a step
    assert @progress.progress_percentage > initial_percentage
  end

  test "should determine next step correctly" do
    @progress.save!
    
    assert_equal 'welcome', @progress.next_step
    
    @progress.mark_step_complete('welcome')
    next_step = @progress.next_step
    assert_not_equal 'welcome', next_step
  end

  test "should handle skip functionality" do
    @progress.save!
    @progress.skip!
    
    assert @progress.skipped?
    assert @progress.complete?
    assert @progress.completed_at.present?
    assert_equal 'complete', @progress.current_step
  end

  test "should be complete when all required steps are done" do
    @progress.save!
    
    # Complete all available steps
    available_steps = @progress.send(:determine_available_steps)
    available_steps.each do |step|
      @progress.mark_step_complete(step)
    end
    
    assert @progress.complete?
    assert @progress.completed_at.present?
  end

  test "should be incomplete initially" do
    @progress.save!
    assert @progress.incomplete?
    assert_not @progress.complete?
  end

  test "should determine available steps based on modules" do
    @progress.save!
    available_steps = @progress.send(:determine_available_steps)
    
    # Should always include welcome and explore_features
    assert_includes available_steps, 'welcome'
    assert_includes available_steps, 'explore_features'
  end
end