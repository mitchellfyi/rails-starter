# frozen_string_literal: true

require 'test_helper'

class SeoMetadataTest < ActiveSupport::TestCase
  def setup
    @post = posts(:published_post)
    @seo = seo_metadata(:post_seo)
  end

  test "should be valid with valid attributes" do
    seo = SeoMetadata.new(
      seo_optimizable: @post,
      meta_title: "Test Title",
      meta_description: "Test description"
    )
    assert seo.valid?
  end

  test "should require meta_title" do
    @seo.meta_title = nil
    assert_not @seo.valid?
    assert_includes @seo.errors[:meta_title], "can't be blank"
  end

  test "should require meta_description" do
    @seo.meta_description = nil
    assert_not @seo.valid?
    assert_includes @seo.errors[:meta_description], "can't be blank"
  end

  test "should validate meta_title length" do
    @seo.meta_title = "a" * 61
    assert_not @seo.valid?
    assert_includes @seo.errors[:meta_title], "is too long (maximum is 60 characters)"
  end

  test "should validate meta_description length" do
    @seo.meta_description = "a" * 161
    assert_not @seo.valid?
    assert_includes @seo.errors[:meta_description], "is too long (maximum is 160 characters)"
  end

  test "should generate robots content" do
    @seo.index_page = true
    @seo.follow_links = true
    assert_equal "index, follow", @seo.robots_content

    @seo.index_page = false
    @seo.follow_links = false
    assert_equal "noindex, nofollow", @seo.robots_content
  end

  test "should generate structured data for blog posts" do
    data = @seo.structured_data
    assert_equal "https://schema.org", data[:@context]
    assert_equal "BlogPosting", data[:@type]
    assert_equal @seo.meta_title, data[:headline]
  end

  test "should set defaults from optimizable content" do
    post = Post.create!(
      title: "My Post Title",
      content: "This is the content of my post",
      author: users(:admin)
    )
    
    seo = SeoMetadata.create!(seo_optimizable: post)
    assert_equal "My Post Title", seo.meta_title
    assert_equal "article", seo.og_type
  end
end