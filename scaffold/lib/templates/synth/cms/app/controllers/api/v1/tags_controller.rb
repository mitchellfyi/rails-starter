# frozen_string_literal: true

class Api::V1::TagsController < Api::V1::BaseController
  before_action :set_tag, only: [:show]

  def index
    @tags = Tag.includes(:posts)
               .joins(:posts)
               .where(posts: { published: true })
               .select('tags.*, COUNT(posts.id) as posts_count')
               .group('tags.id')
               .order('posts_count DESC, tags.name ASC')

    render json: @tags
  end

  def show
    @posts = @tag.posts
                 .published
                 .includes(:author, :category)
                 .recent
                 .page(params[:page])
                 .per(params[:per_page] || 10)

    render json: {
      tag: @tag,
      posts: @posts,
      meta: pagination_meta(@posts)
    }
  end

  private

  def set_tag
    @tag = Tag.friendly.find(params[:id])
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