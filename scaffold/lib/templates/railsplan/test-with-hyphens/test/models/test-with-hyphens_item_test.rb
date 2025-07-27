# frozen_string_literal: true

require 'test_helper'

class TestWithHyphensItemTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @test-with-hyphens_item = TestWithHyphensItem.new(
      user: @user,
      name: "Test Item",
      description: "Test Description"
    )
  end

  test "should be valid" do
    assert @test-with-hyphens_item.valid?
  end

  test "should require name" do
    @test-with-hyphens_item.name = nil
    assert_not @test-with-hyphens_item.valid?
    assert_includes @test-with-hyphens_item.errors[:name], "can't be blank"
  end

  test "should require user" do
    @test-with-hyphens_item.user = nil
    assert_not @test-with-hyphens_item.valid?
    assert_includes @test-with-hyphens_item.errors[:user], "must exist"
  end

  test "name should not be too short" do
    @test-with-hyphens_item.name = "a"
    assert_not @test-with-hyphens_item.valid?
    assert_includes @test-with-hyphens_item.errors[:name], "is too short (minimum is 2 characters)"
  end

  test "name should not be too long" do
    @test-with-hyphens_item.name = "a" * 101
    assert_not @test-with-hyphens_item.valid?
    assert_includes @test-with-hyphens_item.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "description should not be too long" do
    @test-with-hyphens_item.description = "a" * 501
    assert_not @test-with-hyphens_item.valid?
    assert_includes @test-with-hyphens_item.errors[:description], "is too long (maximum is 500 characters)"
  end

  test "should have display_name method" do
    assert_equal "Test Item", @test-with-hyphens_item.display_name
  end

  test "display_name should fallback when name is blank" do
    @test-with-hyphens_item.name = ""
    assert_equal "Untitled TestWithHyphens", @test-with-hyphens_item.display_name
  end

  test "should scope active items" do
    active_item = TestWithHyphensItem.create!(user: @user, name: "Active", active: true)
    inactive_item = TestWithHyphensItem.create!(user: @user, name: "Inactive", active: false)

    assert_includes TestWithHyphensItem.active, active_item
    assert_not_includes TestWithHyphensItem.active, inactive_item
  end

  test "should order recent items" do
    old_item = TestWithHyphensItem.create!(user: @user, name: "Old", created_at: 2.days.ago)
    new_item = TestWithHyphensItem.create!(user: @user, name: "New", created_at: 1.day.ago)

    recent_items = TestWithHyphensItem.recent
    assert_equal new_item, recent_items.first
    assert_equal old_item, recent_items.second
  end
end
