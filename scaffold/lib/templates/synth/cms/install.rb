# frozen_string_literal: true

# Synth CMS module installer for the Rails SaaS starter template.
# This module creates a blog/CMS system using ActionText with SEO features.

say_status :cms, "Installing CMS module with ActionText and SEO"

# Add CMS-specific gems
add_gem 'image_processing', '~> 1.12'
add_gem 'meta-tags', '~> 2.18'
add_gem 'friendly_id', '~> 5.5'
add_gem 'acts_as_taggable_on', '~> 10.0'

after_bundle do
  # Install ActionText if not already installed
  generate 'action_text:install'

  # Generate CMS models
  generate 'model', 'Post', 'title:string', 'slug:string', 'excerpt:text', 'published:boolean', 'published_at:datetime', 'featured:boolean', 'meta_title:string', 'meta_description:text', 'author:references'
  generate 'model', 'Category', 'name:string', 'slug:string', 'description:text', 'color:string'
  generate 'model', 'PostCategory', 'post:references', 'category:references'

  # Generate controllers
  generate 'controller', 'Posts', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
  generate 'controller', 'Categories', 'index', 'show'
  generate 'controller', 'Admin::Posts', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'

  # Create Post model enhancements
  create_file 'app/models/concerns/post_publishing.rb', <<~'RUBY'
    module PostPublishing
      extend ActiveSupport::Concern

      included do
        extend FriendlyId
        friendly_id :title, use: :slugged
        
        acts_as_taggable_on :tags
        
        belongs_to :author, class_name: 'User'
        has_rich_text :content
        has_one_attached :featured_image
        has_many :post_categories, dependent: :destroy
        has_many :categories, through: :post_categories
        
        validates :title, presence: true
        validates :content, presence: true
        validates :author, presence: true
        
        scope :published, -> { where(published: true) }
        scope :featured, -> { where(featured: true) }
        scope :recent, -> { order(published_at: :desc) }
        scope :by_category, ->(category) { joins(:categories).where(categories: { slug: category }) }
        scope :by_tag, ->(tag) { tagged_with(tag) }
      end

      def published?
        published && published_at.present? && published_at <= Time.current
      end

      def reading_time
        words_per_minute = 200
        word_count = content.to_plain_text.split.size
        (word_count / words_per_minute.to_f).ceil
      end

      def seo_title
        meta_title.presence || title
      end

      def seo_description
        meta_description.presence || excerpt.presence || content.to_plain_text.truncate(160)
      end

      def featured_image_url(size: :medium)
        return nil unless featured_image.attached?
        
        case size
        when :small
          featured_image.variant(resize_to_limit: [400, 225])
        when :medium
          featured_image.variant(resize_to_limit: [800, 450])
        when :large
          featured_image.variant(resize_to_limit: [1200, 675])
        else
          featured_image
        end
      end

      def should_generate_new_friendly_id?
        title_changed? || super
      end
    end
  RUBY

  # Create SEO helpers
  create_file 'app/helpers/seo_helper.rb', <<~'RUBY'
    module SeoHelper
      def page_title(title = nil)
        base_title = Rails.application.class.name.split('::').first
        title.present? ? "#{title} | #{base_title}" : base_title
      end

      def page_description(description = nil)
        description.presence || "#{Rails.application.class.name.split('::').first} - Your AI-native SaaS platform"
      end

      def page_keywords(*keywords)
        keywords.flatten.compact.join(', ')
      end

      def structured_data_for_post(post)
        {
          "@context": "https://schema.org",
          "@type": "BlogPosting",
          "headline": post.title,
          "description": post.seo_description,
          "author": {
            "@type": "Person",
            "name": post.author.full_name
          },
          "datePublished": post.published_at&.iso8601,
          "dateModified": post.updated_at.iso8601,
          "image": post.featured_image_url(:large),
          "mainEntityOfPage": {
            "@type": "WebPage",
            "@id": post_url(post)
          }
        }.to_json
      end

      def breadcrumbs(*crumbs)
        content_for :breadcrumbs do
          crumbs.map.with_index do |crumb, index|
            if index == crumbs.length - 1
              content_tag :span, crumb[:name], class: 'current'
            else
              link_to crumb[:name], crumb[:url], class: 'breadcrumb-link'
            end
          end.join(' / ').html_safe
        end
      end
    end
  RUBY

  # Create sitemap generator
  create_file 'app/services/sitemap_generator.rb', <<~'RUBY'
    class SitemapGenerator
      def self.generate
        new.generate
      end

      def generate
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!
        
        xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
          # Homepage
          xml.url do
            xml.loc root_url
            xml.changefreq "daily"
            xml.priority "1.0"
          end

          # Blog posts
          Post.published.find_each do |post|
            xml.url do
              xml.loc post_url(post)
              xml.lastmod post.updated_at.iso8601
              xml.changefreq "weekly"
              xml.priority "0.8"
            end
          end

          # Categories
          Category.find_each do |category|
            xml.url do
              xml.loc category_url(category)
              xml.changefreq "weekly"
              xml.priority "0.6"
            end
          end
        end

        sitemap_path = Rails.root.join('public', 'sitemap.xml')
        File.write(sitemap_path, xml.target!)
        
        Rails.logger.info "Sitemap generated at #{sitemap_path}"
      end

      private

      def root_url
        Rails.application.routes.url_helpers.root_url
      end

      def post_url(post)
        Rails.application.routes.url_helpers.post_url(post)
      end

      def category_url(category)
        Rails.application.routes.url_helpers.category_url(category)
      end
    end
  RUBY

  # Create RSS feed generator
  create_file 'app/views/posts/feed.rss.builder', <<~'RUBY'
    xml.instruct! :xml, version: "1.0"
    xml.rss version: "2.0" do
      xml.channel do
        xml.title "#{Rails.application.class.name.split('::').first} Blog"
        xml.description "Latest posts from our blog"
        xml.link posts_url
        xml.language "en-us"

        @posts.each do |post|
          xml.item do
            xml.title post.title
            xml.description post.excerpt || post.content.to_plain_text.truncate(200)
            xml.pubDate post.published_at.to_formatted_s(:rfc822)
            xml.link post_url(post)
            xml.guid post_url(post)
            xml.author "#{post.author.email} (#{post.author.full_name})"
            
            post.tag_list.each do |tag|
              xml.category tag
            end
          end
        end
      end
    end
  RUBY

  say_status :cms, "CMS module installed. Next steps:"
  say_status :cms, "1. Run rails db:migrate"
  say_status :cms, "2. Add CMS routes"
  say_status :cms, "3. Include PostPublishing concern in Post model"
  say_status :cms, "4. Set up image processing for featured images"
  say_status :cms, "5. Configure meta-tags gem"
end