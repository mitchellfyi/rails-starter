# frozen_string_literal: true

require 'test_helper'

class TestWithHyphensIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "complete test-with-hyphens workflow" do
    # Visit index page
    get test-with-hyphens_index_path
    assert_response :success
    assert_select 'h1', 'TestWithHyphens'

    # Create new item
    get new_test-with-hyphens_path
    assert_response :success

    post test-with-hyphens_index_path, params: {
      test-with-hyphens_item: {
        name: "Integration Test Item",
        description: "Created during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Integration Test Item'

    # Edit the item
    item = TestWithHyphensItem.last
    get edit_test-with-hyphens_path(item)
    assert_response :success

    patch test-with-hyphens_path(item), params: {
      test-with-hyphens_item: {
        name: "Updated Integration Test Item",
        description: "Updated during integration test"
      }
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select 'h1', 'Updated Integration Test Item'

    # Delete the item
    assert_difference('TestWithHyphensItem.count', -1) do
      delete test-with-hyphens_path(item)
    end
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "should handle validation errors gracefully" do
    post test-with-hyphens_index_path, params: {
      test-with-hyphens_item: {
        name: "", # Invalid
        description: "Should not be created"
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.alert-error'
  end
end
