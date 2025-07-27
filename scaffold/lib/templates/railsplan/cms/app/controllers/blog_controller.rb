# frozen_string_literal: true

class BlogController < ApplicationController
  before_action :set_post, only: [:show]
  before_action :set_posts_per_page

  def index
    @posts = Post.published
                 .includes(:category, :tags, :author, :seo_metadata)
                 .recent
                 .page(params[:page])
                 .per(@posts_per_page)

    @featured_posts = Post.featured.published.recent.limit(3)
    @categories = Category.joins(:posts)
                         .where(posts: { published: true })
                         .select('categories.*, COUNT(posts.id) as posts_count')
                         .group('categories.id')
                         .order('posts_count DESC')
                         .limit(10)
    
    @popular_tags = Tag.joins(:posts)
                      .where(posts: { published: true })
                      .select('tags.*, COUNT(posts.id) as posts_count')
                      .group('tags.id')
                      .order('posts_count DESC')
                      .limit(20)

    respond_to do |format|
      format.html
      format.json { render json: @posts }
      format.rss { redirect_to blog_feed_path(format: :rss) }
    end
  end

  def show
    unless @post.published?
      raise ActiveRecord::RecordNotFound
    end

    @post.increment_view_count!
    
    @related_posts = Post.published
                         .where.not(id: @post.id)
                         .includes(:category, :tags, :author)
                         .recent
                         .limit(3)
    
    # Prioritize posts from same category or with same tags
    if @post.category.present?
      @related_posts = @related_posts.where(category: @post.category)
    elsif @post.tags.any?
      @related_posts = @related_posts.joins(:tags)
                                    .where(tags: { id: @post.tag_ids })
                                    .group('posts.id')
                                    .order('COUNT(tags.id) DESC')
    end

    respond_to do |format|
      format.html
      format.json { render json: @post, include: [:category, :tags, :author, :seo_metadata] }
    end
  end

  def category
    @category = Category.friendly.find(params[:slug])
    @posts = @category.posts
                     .published
                     .includes(:category, :tags, :author, :seo_metadata)
                     .recent
                     .page(params[:page])
                     .per(@posts_per_page)

    @page_title = @category.name
    @page_description = @category.description.presence || "Posts in #{@category.name} category"

    respond_to do |format|
      format.html { render :index }
      format.json { render json: @posts }
    end
  end

  def tag
    @tag = Tag.friendly.find(params[:slug])
    @posts = @tag.posts
                 .published
                 .includes(:category, :tags, :author, :seo_metadata)
                 .recent
                 .page(params[:page])
                 .per(@posts_per_page)

    @page_title = "Posts tagged with #{@tag.name}"
    @page_description = @tag.description.presence || "All posts tagged with #{@tag.name}"

    respond_to do |format|
      format.html { render :index }
      format.json { render json: @posts }
    end
  end

  def feed
    @posts = Post.published
                 .includes(:category, :tags, :author)
                 .recent
                 .limit(20)

    respond_to do |format|
      format.rss { render layout: false }
      format.atom { render layout: false }
    end
  end

  def search
    @query = params[:q]&.strip
    @posts = if @query.present?
               Post.published
                   .where("title ILIKE ? OR excerpt ILIKE ?", "%#{@query}%", "%#{@query}%")
                   .includes(:category, :tags, :author, :seo_metadata)
                   .recent
                   .page(params[:page])
                   .per(@posts_per_page)
             else
               Post.none.page(1)
             end

    @page_title = @query.present? ? "Search results for '#{@query}'" : "Search"
    @page_description = "Search blog posts"

    respond_to do |format|
      format.html
      format.json { render json: @posts }
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:slug])
  end

  def set_posts_per_page
    @posts_per_page = Rails.application.config.cms.posts_per_page
  end
end