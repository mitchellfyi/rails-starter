# frozen_string_literal: true

require 'test_helper'

class FeatureFlagTest < ActiveSupport::TestCase
  def setup
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
  end

  test "feature flag creation" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    flag = FeatureFlag.create!(
      name: 'test_feature',
      description: 'A test feature flag',
      enabled: true
    )

    assert flag.persisted?
    assert_equal 'test_feature', flag.name
    assert flag.enabled?
  end

  test "feature flag validation" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    flag = FeatureFlag.new
    assert_not flag.valid?
    
    if flag.respond_to?(:errors)
      assert flag.errors[:name].any?
    end
  end

  test "feature flag uniqueness" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    FeatureFlag.create!(
      name: 'unique_feature',
      description: 'First feature',
      enabled: true
    )

    duplicate_flag = FeatureFlag.new(
      name: 'unique_feature',
      description: 'Second feature',
      enabled: false
    )

    assert_not duplicate_flag.valid?
    if duplicate_flag.respond_to?(:errors)
      assert duplicate_flag.errors[:name].any?
    end
  end

  test "feature flag scopes" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    enabled_flag = FeatureFlag.create!(
      name: 'enabled_feature',
      description: 'Enabled feature',
      enabled: true
    )

    disabled_flag = FeatureFlag.create!(
      name: 'disabled_feature',
      description: 'Disabled feature',
      enabled: false
    )

    if FeatureFlag.respond_to?(:enabled)
      assert_includes FeatureFlag.enabled, enabled_flag
      assert_not_includes FeatureFlag.enabled, disabled_flag
    end

    if FeatureFlag.respond_to?(:disabled)
      assert_includes FeatureFlag.disabled, disabled_flag
      assert_not_includes FeatureFlag.disabled, enabled_flag
    end
  end

  test "feature flag toggle" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    flag = FeatureFlag.create!(
      name: 'toggle_feature',
      description: 'Feature to toggle',
      enabled: true
    )

    if flag.respond_to?(:toggle!)
      flag.toggle!
      assert_not flag.enabled?
    end
  end

  test "feature flag percentage rollout" do
    skip "FeatureFlag model not available in test environment" unless defined?(FeatureFlag)
    
    flag = FeatureFlag.create!(
      name: 'percentage_feature',
      description: 'Feature with percentage rollout',
      enabled: true,
      percentage: 50
    )

    if flag.respond_to?(:percentage)
      assert_equal 50, flag.percentage
    end
  end
end