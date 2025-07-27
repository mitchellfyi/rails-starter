# frozen_string_literal: true

require 'test_helper'

class TestFeatureIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "complete test_feature workflow" do
    # Visit index page
    get test_feature_index_path
    assert_response :success
    assert_select 'h1', 'TestFeature'

    # Create new item
    get new_test_feature_path
    assert_response :success

    post test_feature_index_path, params: {
      test_feature_item: {
        name: "Integration Test Item",
        description: "Created during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Integration Test Item'

    # Edit the item
    item = TestFeatureItem.last
    get edit_test_feature_path(item)
    assert_response :success

    patch test_feature_path(item), params: {
      test_feature_item: {
        name: "Updated Integration Test Item",
        description: "Updated during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Updated Integration Test Item'

    # Delete the item
    assert_difference('TestFeatureItem.count', -1) do
      delete test_feature_path(item)
    end
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "should handle validation errors gracefully" do
    post test_feature_index_path, params: {
      test_feature_item: {
        name: "", # Invalid
        description: "Should not be created"
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.alert-error'
  end
end
