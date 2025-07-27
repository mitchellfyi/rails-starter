# frozen_string_literal: true

require 'test_helper'

class TestWithHyphensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @test-with-hyphens_item = test-with-hyphens_items(:one)
    sign_in @user
  end

  test "should get index" do
    get test-with-hyphens_index_url
    assert_response :success
  end

  test "should get new" do
    get new_test-with-hyphens_url
    assert_response :success
  end

  test "should create test-with-hyphens_item" do
    assert_difference('TestWithHyphensItem.count') do
      post test-with-hyphens_index_url, params: { 
        test-with-hyphens_item: { 
          name: "Test Item", 
          description: "Test Description" 
        } 
      }
    end

    assert_redirected_to test-with-hyphens_url(TestWithHyphensItem.last)
  end

  test "should show test-with-hyphens_item" do
    get test-with-hyphens_url(@test-with-hyphens_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_test-with-hyphens_url(@test-with-hyphens_item)
    assert_response :success
  end

  test "should update test-with-hyphens_item" do
    patch test-with-hyphens_url(@test-with-hyphens_item), params: { 
      test-with-hyphens_item: { 
        name: @test-with-hyphens_item.name, 
        description: "Updated Description" 
      } 
    }
    assert_redirected_to test-with-hyphens_url(@test-with-hyphens_item)
  end

  test "should destroy test-with-hyphens_item" do
    assert_difference('TestWithHyphensItem.count', -1) do
      delete test-with-hyphens_url(@test-with-hyphens_item)
    end

    assert_redirected_to test-with-hyphens_index_url
  end

  test "should not access other user's items" do
    other_user = users(:two)
    other_item = TestWithHyphensItem.create!(
      user: other_user, 
      name: "Other User Item"
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      get test-with-hyphens_url(other_item)
    end
  end
end
