# frozen_string_literal: true

require 'test_helper'

class PostTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @category = categories(:tutorials)
    @post = posts(:published_post)
  end

  test "should be valid with valid attributes" do
    post = Post.new(
      title: "Test Post",
      content: "Test content",
      author: @user,
      category: @category
    )
    assert post.valid?
  end

  test "should require title" do
    @post.title = nil
    assert_not @post.valid?
    assert_includes @post.errors[:title], "can't be blank"
  end

  test "should require content" do
    @post.content = nil
    assert_not @post.valid?
    assert_includes @post.errors[:content], "can't be blank"
  end

  test "should generate slug from title" do
    post = Post.create!(
      title: "My Awesome Blog Post",
      content: "Test content",
      author: @user
    )
    assert_equal "my-awesome-blog-post", post.slug
  end

  test "should scope published posts" do
    published_count = Post.published.count
    assert_equal 1, published_count
  end

  test "should calculate reading time" do
    content = "word " * 200 # 200 words
    post = Post.create!(
      title: "Test Post",
      content: content,
      author: @user
    )
    assert_equal 1, post.reading_time
  end

  test "should set published_at when published" do
    @post.update!(published: true)
    assert_not_nil @post.published_at
  end

  test "should find next and previous posts" do
    # Create a sequence of posts
    past_post = Post.create!(
      title: "Past Post",
      content: "Content",
      author: @user,
      published: true,
      published_at: 2.days.ago
    )
    
    current_post = Post.create!(
      title: "Current Post", 
      content: "Content",
      author: @user,
      published: true,
      published_at: 1.day.ago
    )
    
    future_post = Post.create!(
      title: "Future Post",
      content: "Content", 
      author: @user,
      published: true,
      published_at: Time.current
    )

    assert_equal future_post, current_post.next_post
    assert_equal past_post, current_post.previous_post
  end

  test "should handle tag names assignment" do
    @post.tag_names = "Rails, Ruby, Tutorial"
    @post.save!
    
    assert_equal 3, @post.tags.count
    assert_includes @post.tag_names, "Rails"
    assert_includes @post.tag_names, "Ruby" 
    assert_includes @post.tag_names, "Tutorial"
  end
end