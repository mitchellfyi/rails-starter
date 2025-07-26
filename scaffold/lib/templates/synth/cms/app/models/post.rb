# frozen_string_literal: true

class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  has_rich_text :content
  belongs_to :category, optional: true
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_one :seo_metadata, as: :seo_optimizable, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :excerpt, length: { maximum: 500 }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :with_tag, ->(tag) { joins(:tags).where(tags: { id: tag.id }) }

  before_save :set_published_at
  before_save :calculate_reading_time
  after_update :expire_cache

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

  def next_post
    Post.published
        .where('published_at > ?', published_at)
        .order(published_at: :asc)
        .first
  end

  def previous_post
    Post.published
        .where('published_at < ?', published_at)
        .order(published_at: :desc)
        .first
  end

  def increment_view_count!
    increment!(:view_count)
  end

  def tag_names
    tags.pluck(:name)
  end

  def tag_names=(names)
    self.tags = names.split(',').map(&:strip).reject(&:blank?).map do |name|
      Tag.find_or_create_by(name: name.titleize)
    end
  end

  private

  def set_published_at
    if published_changed? && published?
      self.published_at ||= Time.current
    elsif !published?
      self.published_at = nil
    end
  end

  def calculate_reading_time
    return unless content.present?
    
    word_count = content.to_plain_text.split.size
    self.reading_time = (word_count / 200.0).ceil # Assuming 200 words per minute
  end

  def expire_cache
    return unless Rails.application.config.cms.enable_caching
    
    Rails.cache.delete("posts/index")
    Rails.cache.delete("posts/featured")
    Rails.cache.delete("post/#{slug}")
    
    # Expire category cache if category changed
    if category_id_changed?
      Rails.cache.delete("posts/category/#{category&.slug}")
    end
  end
end