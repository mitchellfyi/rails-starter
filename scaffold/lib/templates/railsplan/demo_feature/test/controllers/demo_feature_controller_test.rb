# frozen_string_literal: true

require 'test_helper'

class DemoFeatureControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @demo_feature_item = demo_feature_items(:one)
    sign_in @user
  end

  test "should get index" do
    get demo_feature_index_url
    assert_response :success
  end

  test "should get new" do
    get new_demo_feature_url
    assert_response :success
  end

  test "should create demo_feature_item" do
    assert_difference('DemoFeatureItem.count') do
      post demo_feature_index_url, params: { 
        demo_feature_item: { 
          name: "Test Item", 
          description: "Test Description" 
        } 
      }
    end

    assert_redirected_to demo_feature_url(DemoFeatureItem.last)
  end

  test "should show demo_feature_item" do
    get demo_feature_url(@demo_feature_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_demo_feature_url(@demo_feature_item)
    assert_response :success
  end

  test "should update demo_feature_item" do
    patch demo_feature_url(@demo_feature_item), params: { 
      demo_feature_item: { 
        name: @demo_feature_item.name, 
        description: "Updated Description" 
      } 
    }
    assert_redirected_to demo_feature_url(@demo_feature_item)
  end

  test "should destroy demo_feature_item" do
    assert_difference('DemoFeatureItem.count', -1) do
      delete demo_feature_url(@demo_feature_item)
    end

    assert_redirected_to demo_feature_index_url
  end

  test "should not access other user's items" do
    other_user = users(:two)
    other_item = DemoFeatureItem.create!(
      user: other_user, 
      name: "Other User Item"
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      get demo_feature_url(other_item)
    end
  end
end
