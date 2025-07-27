# frozen_string_literal: true

require 'test_helper'

class DemoFeatureServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @service = DemoFeatureService.new(@user)
  end

  test "should initialize with user" do
    assert_equal @user, @service.user
    assert_empty @service.errors
  end

  test "should create item successfully" do
    attributes = { name: "Test Item", description: "Test Description" }
    
    assert_difference('DemoFeatureItem.count') do
      item = @service.create_item(attributes)
      assert_not_nil item
      assert_equal "Test Item", item.name
      assert_equal "Test Description", item.description
      assert_equal @user, item.user
    end
    
    assert @service.valid?
  end

  test "should not create invalid item" do
    attributes = { name: "" } # Invalid name
    
    assert_no_difference('DemoFeatureItem.count') do
      item = @service.create_item(attributes)
      assert_nil item
    end
    
    assert_not @service.valid?
    assert_not_empty @service.errors
  end

  test "should update item successfully" do
    item = DemoFeatureItem.create!(user: @user, name: "Original Name")
    
    updated_item = @service.update_item(item, { name: "Updated Name" })
    
    assert_not_nil updated_item
    assert_equal "Updated Name", updated_item.name
    assert @service.valid?
  end

  test "should not update item with invalid data" do
    item = DemoFeatureItem.create!(user: @user, name: "Original Name")
    
    updated_item = @service.update_item(item, { name: "" })
    
    assert_nil updated_item
    assert_not @service.valid?
    assert_not_empty @service.errors
  end

  test "should delete item successfully" do
    item = DemoFeatureItem.create!(user: @user, name: "To Delete")
    
    assert_difference('DemoFeatureItem.count', -1) do
      result = @service.delete_item(item)
      assert result
    end
    
    assert @service.valid?
  end
end
