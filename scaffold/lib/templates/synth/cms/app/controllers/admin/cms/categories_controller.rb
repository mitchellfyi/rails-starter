# frozen_string_literal: true

class Admin::Cms::CategoriesController < Admin::Cms::BaseController
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    set_breadcrumbs('Categories')
    @categories = Category.includes(:parent, :children, :posts)
                         .ordered
  end

  def show
    set_breadcrumbs('Categories', @category.name)
    @posts = @category.posts.includes(:author).order(created_at: :desc).limit(10)
  end

  def new
    set_breadcrumbs('Categories', 'New Category')
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to admin_cms_categories_path, notice: 'Category was successfully created.'
    else
      set_breadcrumbs('Categories', 'New Category')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_breadcrumbs('Categories', @category.name, 'Edit')
  end

  def update
    if @category.update(category_params)
      redirect_to admin_cms_categories_path, notice: 'Category was successfully updated.'
    else
      set_breadcrumbs('Categories', @category.name, 'Edit')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.posts.exists?
      redirect_to admin_cms_categories_path, alert: 'Cannot delete category with posts. Move posts to another category first.'
    else
      @category.destroy
      redirect_to admin_cms_categories_path, notice: 'Category was successfully deleted.'
    end
  end

  private

  def set_category
    @category = Category.friendly.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :parent_id, :sort_order)
  end
end