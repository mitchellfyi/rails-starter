# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  before_action :set_category, only: [:show]

  def index
    @categories = Category.includes(:posts)
                         .joins(:posts)
                         .where(posts: { published: true })
                         .select('categories.*, COUNT(posts.id) as posts_count')
                         .group('categories.id')
                         .ordered

    render json: @categories
  end

  def show
    @posts = @category.posts
                     .published
                     .includes(:author, :tags)
                     .recent
                     .page(params[:page])
                     .per(params[:per_page] || 10)

    render json: {
      category: @category,
      posts: @posts,
      meta: pagination_meta(@posts)
    }
  end

  private

  def set_category
    @category = Category.friendly.find(params[:id])
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end