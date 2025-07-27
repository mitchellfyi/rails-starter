# frozen_string_literal: true

require 'test_helper'

class TestFeatureControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @test_feature_item = test_feature_items(:one)
    sign_in @user
  end

  test "should get index" do
    get test_feature_index_url
    assert_response :success
  end

  test "should get new" do
    get new_test_feature_url
    assert_response :success
  end

  test "should create test_feature_item" do
    assert_difference('TestFeatureItem.count') do
      post test_feature_index_url, params: { 
        test_feature_item: { 
          name: "Test Item", 
          description: "Test Description" 
        } 
      }
    end

    assert_redirected_to test_feature_url(TestFeatureItem.last)
  end

  test "should show test_feature_item" do
    get test_feature_url(@test_feature_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_test_feature_url(@test_feature_item)
    assert_response :success
  end

  test "should update test_feature_item" do
    patch test_feature_url(@test_feature_item), params: { 
      test_feature_item: { 
        name: @test_feature_item.name, 
        description: "Updated Description" 
      } 
    }
    assert_redirected_to test_feature_url(@test_feature_item)
  end

  test "should destroy test_feature_item" do
    assert_difference('TestFeatureItem.count', -1) do
      delete test_feature_url(@test_feature_item)
    end

    assert_redirected_to test_feature_index_url
  end

  test "should not access other user's items" do
    other_user = users(:two)
    other_item = TestFeatureItem.create!(
      user: other_user, 
      name: "Other User Item"
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      get test_feature_url(other_item)
    end
  end
end
