# frozen_string_literal: true

class Tag < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :post_tags, dependent: :destroy
  has_many :posts, through: :post_tags

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :description, length: { maximum: 255 }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }

  scope :ordered, -> { order(:name) }
  scope :popular, -> { joins(:posts).group('tags.id').order('COUNT(posts.id) DESC') }

  def should_generate_new_friendly_id?
    name_changed? || slug.blank?
  end

  def published_posts
    posts.published
  end

  def published_posts_count
    posts.published.count
  end

  def usage_count
    posts.count
  end

  def self.popular_tags(limit = 10)
    joins(:post_tags)
      .select('tags.*, COUNT(post_tags.id) as usage_count')
      .group('tags.id')
      .order('usage_count DESC')
      .limit(limit)
  end

  def self.tag_cloud(limit = 20)
    tags = popular_tags(limit)
    return [] if tags.empty?

    min_count = tags.last.usage_count.to_f
    max_count = tags.first.usage_count.to_f
    
    tags.map do |tag|
      # Calculate relative size (1-5 scale)
      relative_size = if max_count == min_count
                       3
                     else
                       ((tag.usage_count - min_count) / (max_count - min_count) * 4) + 1
                     end
      
      {
        tag: tag,
        size: relative_size.round
      }
    end
  end

  def self.find_or_create_from_list(tag_names)
    return [] if tag_names.blank?
    
    names = tag_names.is_a?(String) ? tag_names.split(',') : tag_names
    names = names.map(&:strip).reject(&:blank?).map(&:titleize).uniq
    
    names.map do |name|
      find_or_create_by(name: name) do |tag|
        # Assign a random color if not specified
        tag.color = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899"].sample
      end
    end
  end
end