# frozen_string_literal: true

require 'test_helper'

class DemoFeatureIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "complete demo_feature workflow" do
    # Visit index page
    get demo_feature_index_path
    assert_response :success
    assert_select 'h1', 'DemoFeature'

    # Create new item
    get new_demo_feature_path
    assert_response :success

    post demo_feature_index_path, params: {
      demo_feature_item: {
        name: "Integration Test Item",
        description: "Created during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Integration Test Item'

    # Edit the item
    item = DemoFeatureItem.last
    get edit_demo_feature_path(item)
    assert_response :success

    patch demo_feature_path(item), params: {
      demo_feature_item: {
        name: "Updated Integration Test Item",
        description: "Updated during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Updated Integration Test Item'

    # Delete the item
    assert_difference('DemoFeatureItem.count', -1) do
      delete demo_feature_path(item)
    end
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "should handle validation errors gracefully" do
    post demo_feature_index_path, params: {
      demo_feature_item: {
        name: "", # Invalid
        description: "Should not be created"
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.alert-error'
  end
end
