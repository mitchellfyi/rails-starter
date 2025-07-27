# frozen_string_literal: true

require 'test_helper'

class BlogControllerTest < ActionDispatch::IntegrationTest
  def setup
    @post = posts(:published_post)
    @category = categories(:tutorials)
    @tag = tags(:rails)
  end

  test "should get index" do
    get blog_path
    assert_response :success
    assert_includes response.body, @post.title
  end

  test "should show published post" do
    get blog_post_path(@post.slug)
    assert_response :success
    assert_includes response.body, @post.title
  end

  test "should not show unpublished post" do
    @post.update!(published: false)
    assert_raises(ActiveRecord::RecordNotFound) do
      get blog_post_path(@post.slug)
    end
  end

  test "should increment view count when viewing post" do
    initial_count = @post.view_count
    get blog_post_path(@post.slug)
    @post.reload
    assert_equal initial_count + 1, @post.view_count
  end

  test "should filter posts by category" do
    get blog_category_path(@category.slug)
    assert_response :success
    assert_includes response.body, @post.title
  end

  test "should filter posts by tag" do
    get blog_tag_path(@tag.slug)
    assert_response :success
  end

  test "should search posts" do
    get blog_path, params: { q: @post.title }
    assert_response :success
    assert_includes response.body, @post.title
  end

  test "should return JSON for API requests" do
    get blog_path, headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type
  end
end