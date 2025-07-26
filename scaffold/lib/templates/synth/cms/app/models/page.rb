# frozen_string_literal: true

class Page < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  has_rich_text :content
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  has_one :seo_metadata, as: :seo_optimizable, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :excerpt, length: { maximum: 500 }
  validates :template_name, presence: true

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :ordered, -> { order(:sort_order, :title) }

  before_save :set_published_at
  after_update :expire_cache

  TEMPLATE_OPTIONS = %w[
    default
    landing
    about
    contact
    legal
    full_width
  ].freeze

  def published?
    published && published_at.present?
  end

  def should_generate_new_friendly_id?
    title_changed? || slug.blank?
  end

  def excerpt_or_content(limit: 200)
    return excerpt if excerpt.present?
    
    plain_content = content.to_plain_text
    plain_content.length > limit ? "#{plain_content[0...limit]}..." : plain_content
  end

  def template_partial
    "pages/templates/#{template_name}"
  end

  def self.template_options
    TEMPLATE_OPTIONS.map { |template| [template.humanize, template] }
  end

  private

  def set_published_at
    if published_changed? && published?
      self.published_at ||= Time.current
    elsif !published?
      self.published_at = nil
    end
  end

  def expire_cache
    return unless Rails.application.config.cms.enable_caching
    
    Rails.cache.delete("page/#{slug}")
    Rails.cache.delete("pages/index")
  end
end