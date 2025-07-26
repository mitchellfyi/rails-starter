# frozen_string_literal: true

class Admin::Cms::PostsController < Admin::Cms::BaseController
  before_action :set_post, only: [:show, :edit, :update, :destroy, :publish, :unpublish]
  before_action :set_categories_and_tags, only: [:new, :create, :edit, :update]

  def index
    set_breadcrumbs('Posts')
    
    @posts = Post.includes(:author, :category, :tags)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(20)

    @posts = @posts.where(published: params[:status] == 'published') if params[:status] == 'published'
    @posts = @posts.where(published: false) if params[:status] == 'draft'
    @posts = @posts.where(category_id: params[:category_id]) if params[:category_id].present?
    @posts = @posts.where("title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def show
    set_breadcrumbs('Posts', @post.title)
  end

  def new
    set_breadcrumbs('Posts', 'New Post')
    @post = Post.new
    @post.build_seo_metadata
  end

  def create
    @post = current_user.authored_posts.build(post_params)
    @post.build_seo_metadata(seo_metadata_params) if seo_metadata_params.present?

    if @post.save
      redirect_to admin_cms_post_path(@post), notice: 'Post was successfully created.'
    else
      set_breadcrumbs('Posts', 'New Post')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_breadcrumbs('Posts', @post.title, 'Edit')
    @post.build_seo_metadata unless @post.seo_metadata
  end

  def update
    if @post.update(post_params)
      @post.seo_metadata&.update(seo_metadata_params) if seo_metadata_params.present?
      redirect_to admin_cms_post_path(@post), notice: 'Post was successfully updated.'
    else
      set_breadcrumbs('Posts', @post.title, 'Edit')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_cms_posts_path, notice: 'Post was successfully deleted.'
  end

  def publish
    @post.update!(published: true, published_at: Time.current)
    redirect_to admin_cms_post_path(@post), notice: 'Post was successfully published.'
  end

  def unpublish
    @post.update!(published: false, published_at: nil)
    redirect_to admin_cms_post_path(@post), notice: 'Post was successfully unpublished.'
  end

  private

  def set_post
    @post = Post.friendly.find(params[:id])
  end

  def set_categories_and_tags
    @categories = Category.ordered
    @tags = Tag.ordered
  end

  def post_params
    params.require(:post).permit(
      :title, :content, :excerpt, :category_id, :published, :featured,
      tag_ids: [], tag_names: []
    )
  end

  def seo_metadata_params
    return {} unless params[:post][:seo_metadata_attributes]
    
    params.require(:post)[:seo_metadata_attributes].permit(
      :meta_title, :meta_description, :meta_keywords, :canonical_url,
      :og_title, :og_description, :og_image_url, :og_type,
      :index_page, :follow_links
    )
  end
end