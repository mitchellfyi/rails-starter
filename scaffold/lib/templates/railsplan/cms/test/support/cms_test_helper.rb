# frozen_string_literal: true

# CMS Test Helper
# Provides helper methods for testing CMS functionality

module CmsTestHelper
  def create_test_post(attributes = {})
    default_attributes = {
      title: "Test Post",
      content: "Test content for the post",
      author: users(:admin),
      published: true
    }
    
    Post.create!(default_attributes.merge(attributes))
  end

  def create_test_page(attributes = {})
    default_attributes = {
      title: "Test Page",
      content: "Test content for the page",
      author: users(:admin),
      published: true,
      template_name: "default"
    }
    
    Page.create!(default_attributes.merge(attributes))
  end

  def create_test_category(attributes = {})
    default_attributes = {
      name: "Test Category"
    }
    
    Category.create!(default_attributes.merge(attributes))
  end

  def create_test_tag(attributes = {})
    default_attributes = {
      name: "Test Tag",
      color: "#3B82F6"
    }
    
    Tag.create!(default_attributes.merge(attributes))
  end

  def create_test_seo_metadata(optimizable, attributes = {})
    default_attributes = {
      meta_title: "Test SEO Title",
      meta_description: "Test SEO description for the content"
    }
    
    optimizable.create_seo_metadata!(default_attributes.merge(attributes))
  end

  def assert_seo_optimized(content)
    assert content.seo_metadata.present?, "Content should have SEO metadata"
    assert content.seo_metadata.meta_title.present?, "SEO metadata should have meta_title"
    assert content.seo_metadata.meta_description.present?, "SEO metadata should have meta_description"
  end

  def assert_valid_sitemap
    get '/sitemap.xml'
    assert_response :success
    assert_equal 'application/xml', response.content_type
    
    # Parse XML to ensure it's valid
    doc = Nokogiri::XML(response.body)
    assert doc.errors.empty?, "Sitemap XML should be valid"
    assert doc.css('urlset url').any?, "Sitemap should contain URLs"
  end

  def assert_seo_meta_tags_present(content = nil)
    assert_select 'title'
    assert_select 'meta[name="description"]'
    assert_select 'meta[property="og:title"]'
    assert_select 'meta[property="og:description"]'
    assert_select 'meta[property="og:type"]'
    
    if content&.is_a?(Post)
      assert_select 'script[type="application/ld+json"]'
    end
  end

  def stub_cms_config
    original_config = Rails.application.config.cms
    test_config = ActiveSupport::OrderedOptions.new
    test_config.default_meta_description = "Test site description"
    test_config.sitemap_host = "http://test.example.com"
    test_config.posts_per_page = 5
    test_config.enable_caching = false
    
    Rails.application.config.cms = test_config
    
    yield if block_given?
    
    Rails.application.config.cms = original_config
  end

  def login_as_admin
    post '/users/sign_in', params: {
      user: {
        email: users(:admin).email,
        password: 'password'
      }
    }
  end

  def assert_admin_required
    assert_redirected_to root_path
    assert_equal 'You are not authorized to access this page.', flash[:alert]
  end
end