# frozen_string_literal: true

require 'test_helper'

class ModuleDetectorTest < ActiveSupport::TestCase
  def setup
    @detector = ModuleDetector.new
  end

  test "should detect when workspace module is available" do
    # Mock the Workspace constant
    if defined?(Workspace)
      assert @detector.workspace_module_available?
    else
      assert_not @detector.workspace_module_available?
    end
  end

  test "should detect when billing module is available" do
    # Mock the Subscription constant
    if defined?(Subscription)
      assert @detector.billing_module_available?
    else
      assert_not @detector.billing_module_available?
    end
  end

  test "should detect when ai module is available" do
    # Mock the LLMOutput constant
    if defined?(LLMOutput)
      assert @detector.ai_module_available?
    else
      assert_not @detector.ai_module_available?
    end
  end

  test "should detect when admin module is available" do
    # Mock the AdminUser constant
    if defined?(AdminUser)
      assert @detector.admin_module_available?
    else
      assert_not @detector.admin_module_available?
    end
  end

  test "should detect when cms module is available" do
    # Mock the Post constant
    if defined?(Post)
      assert @detector.cms_module_available?
    else
      assert_not @detector.cms_module_available?
    end
  end

  test "should return list of available modules" do
    modules = @detector.available_modules
    assert modules.is_a?(Array)
    
    # Check that modules only contain valid module names
    valid_modules = %w[workspace billing ai admin cms]
    modules.each do |module_name|
      assert_includes valid_modules, module_name
    end
  end

  test "should count available modules correctly" do
    count = @detector.module_count
    assert count.is_a?(Integer)
    assert count >= 0
    assert_equal @detector.available_modules.length, count
  end

  test "should handle missing constants gracefully" do
    # Test that it doesn't crash when constants are not defined
    assert_nothing_raised do
      @detector.workspace_module_available?
      @detector.billing_module_available?
      @detector.ai_module_available?
      @detector.admin_module_available?
      @detector.cms_module_available?
    end
  end
end