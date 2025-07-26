# frozen_string_literal: true

class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :posts, dependent: :nullify
  belongs_to :parent, class_name: 'Category', optional: true
  has_many :children, class_name: 'Category', foreign_key: 'parent_id', dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :root_categories, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:sort_order, :name) }

  before_destroy :check_for_posts

  def should_generate_new_friendly_id?
    name_changed? || slug.blank?
  end

  def published_posts
    posts.published
  end

  def published_posts_count
    posts.published.count
  end

  def hierarchy_path
    return name if parent.nil?
    "#{parent.hierarchy_path} > #{name}"
  end

  def breadcrumb_path
    path = []
    current = self
    while current
      path.unshift(current)
      current = current.parent
    end
    path
  end

  def descendants
    children.includes(:children).flat_map { |child| [child] + child.descendants }
  end

  def self.build_tree(categories = nil)
    categories ||= includes(:children).ordered
    categories.select { |category| category.parent_id.nil? }
  end

  def self.nested_options(categories = nil, prefix = '')
    options = []
    categories ||= root_categories.ordered.includes(:children)
    
    categories.each do |category|
      options << ["#{prefix}#{category.name}", category.id]
      if category.children.any?
        options.concat(nested_options(category.children.ordered, "#{prefix}#{category.name} > "))
      end
    end
    
    options
  end

  private

  def check_for_posts
    if posts.exists?
      errors.add(:base, "Cannot delete category with posts. Move posts to another category first.")
      throw :abort
    end
  end
end