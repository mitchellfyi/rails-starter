# frozen_string_literal: true

class SeoMetadata < ApplicationRecord
  belongs_to :seo_optimizable, polymorphic: true

  validates :meta_title, presence: true, length: { maximum: 60 }
  validates :meta_description, presence: true, length: { maximum: 160 }
  validates :meta_keywords, length: { maximum: 255 }
  validates :canonical_url, format: { with: URI::DEFAULT_PARSER.make_regexp, allow_blank: true }
  validates :og_title, length: { maximum: 95 }
  validates :og_description, length: { maximum: 297 }
  validates :og_type, inclusion: { in: %w[website article blog] }

  before_validation :set_defaults

  def robots_content
    directives = []
    directives << (index_page? ? 'index' : 'noindex')
    directives << (follow_links? ? 'follow' : 'nofollow')
    directives.join(', ')
  end

  def og_title_or_default
    og_title.presence || meta_title
  end

  def og_description_or_default
    og_description.presence || meta_description
  end

  def canonical_url_or_default
    return canonical_url if canonical_url.present?
    
    case seo_optimizable
    when Post
      Rails.application.routes.url_helpers.blog_post_url(seo_optimizable.slug, host: default_host)
    when Page
      Rails.application.routes.url_helpers.page_url(seo_optimizable.slug, host: default_host)
    end
  rescue
    nil
  end

  def structured_data
    return {} unless seo_optimizable.is_a?(Post)
    
    post = seo_optimizable
    {
      "@context": "https://schema.org",
      "@type": "BlogPosting",
      "headline": meta_title,
      "description": meta_description,
      "author": {
        "@type": "Person",
        "name": post.author&.name || "Anonymous"
      },
      "datePublished": post.published_at&.iso8601,
      "dateModified": post.updated_at&.iso8601,
      "url": canonical_url_or_default,
      "keywords": meta_keywords,
      "articleSection": post.category&.name,
      "wordCount": post.content&.to_plain_text&.split&.size
    }.compact
  end

  private

  def set_defaults
    if seo_optimizable.present?
      self.meta_title ||= seo_optimizable.title
      self.meta_description ||= extract_description
      self.og_title ||= meta_title
      self.og_description ||= meta_description
      self.og_type ||= seo_optimizable.is_a?(Post) ? 'article' : 'website'
    end
  end

  def extract_description
    return seo_optimizable.excerpt if seo_optimizable.respond_to?(:excerpt) && seo_optimizable.excerpt.present?
    
    if seo_optimizable.respond_to?(:content) && seo_optimizable.content.present?
      plain_text = seo_optimizable.content.to_plain_text
      plain_text.length > 160 ? "#{plain_text[0...157]}..." : plain_text
    else
      Rails.application.config.cms.default_meta_description
    end
  end

  def default_host
    Rails.application.config.cms.sitemap_host
  end
end