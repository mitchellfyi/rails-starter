# frozen_string_literal: true

class Admin::Cms::TagsController < Admin::Cms::BaseController
  before_action :set_tag, only: [:show, :edit, :update, :destroy]

  def index
    set_breadcrumbs('Tags')
    @tags = Tag.includes(:posts)
               .left_joins(:posts)
               .select('tags.*, COUNT(posts.id) as posts_count')
               .group('tags.id')
               .order('posts_count DESC, tags.name ASC')
               .page(params[:page])
               .per(30)

    @tags = @tags.where("tags.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def show
    set_breadcrumbs('Tags', @tag.name)
    @posts = @tag.posts.includes(:author, :category).order(created_at: :desc).limit(10)
  end

  def new
    set_breadcrumbs('Tags', 'New Tag')
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)

    if @tag.save
      redirect_to admin_cms_tags_path, notice: 'Tag was successfully created.'
    else
      set_breadcrumbs('Tags', 'New Tag')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_breadcrumbs('Tags', @tag.name, 'Edit')
  end

  def update
    if @tag.update(tag_params)
      redirect_to admin_cms_tags_path, notice: 'Tag was successfully updated.'
    else
      set_breadcrumbs('Tags', @tag.name, 'Edit')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy
    redirect_to admin_cms_tags_path, notice: 'Tag was successfully deleted.'
  end

  private

  def set_tag
    @tag = Tag.friendly.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :description, :color)
  end
end