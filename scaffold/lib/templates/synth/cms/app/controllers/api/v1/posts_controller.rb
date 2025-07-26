# frozen_string_literal: true

class Api::V1::PostsController < Api::V1::BaseController
  before_action :set_post, only: [:show]

  def index
    @posts = Post.published
                 .includes(:category, :tags, :author, :seo_metadata)
                 .recent
                 .page(params[:page])
                 .per(params[:per_page] || 10)

    render json: @posts, include: [:category, :tags, :author], meta: pagination_meta(@posts)
  end

  def show
    render json: @post, include: [:category, :tags, :author, :seo_metadata]
  end

  def published
    @posts = Post.published
                 .includes(:category, :tags, :author)
                 .recent
                 .limit(params[:limit] || 20)

    render json: @posts, include: [:category, :tags, :author]
  end

  def recent
    @posts = Post.published
                 .includes(:category, :tags, :author)
                 .recent
                 .limit(params[:limit] || 10)

    render json: @posts, include: [:category, :tags, :author]
  end

  private

  def set_post
    @post = Post.friendly.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @post.published?
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