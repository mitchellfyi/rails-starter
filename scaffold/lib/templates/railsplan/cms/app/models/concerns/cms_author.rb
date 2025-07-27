# frozen_string_literal: true

# This concern extends the User model with CMS functionality
module CmsAuthor
  extend ActiveSupport::Concern

  included do
    has_many :authored_posts, class_name: 'Post', foreign_key: 'author_id', dependent: :destroy
    has_many :authored_pages, class_name: 'Page', foreign_key: 'author_id', dependent: :destroy
  end

  def published_posts
    authored_posts.published
  end

  def published_pages
    authored_pages.published
  end

  def total_posts_count
    authored_posts.count
  end

  def total_pages_count
    authored_pages.count
  end

  def display_name
    name.presence || email.split('@').first.humanize
  end
end