# frozen_string_literal: true

class Admin::Cms::PagesController < Admin::Cms::BaseController
  before_action :set_page, only: [:show, :edit, :update, :destroy, :publish, :unpublish]

  def index
    set_breadcrumbs('Pages')
    
    @pages = Page.includes(:author)
                 .order(:sort_order, :title)
                 .page(params[:page])
                 .per(20)

    @pages = @pages.where(published: params[:status] == 'published') if params[:status] == 'published'
    @pages = @pages.where(published: false) if params[:status] == 'draft'
    @pages = @pages.where("title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def show
    set_breadcrumbs('Pages', @page.title)
  end

  def new
    set_breadcrumbs('Pages', 'New Page')
    @page = Page.new(template_name: 'default')
    @page.build_seo_metadata
  end

  def create
    @page = current_user.authored_pages.build(page_params)
    @page.build_seo_metadata(seo_metadata_params) if seo_metadata_params.present?

    if @page.save
      redirect_to admin_cms_page_path(@page), notice: 'Page was successfully created.'
    else
      set_breadcrumbs('Pages', 'New Page')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_breadcrumbs('Pages', @page.title, 'Edit')
    @page.build_seo_metadata unless @page.seo_metadata
  end

  def update
    if @page.update(page_params)
      @page.seo_metadata&.update(seo_metadata_params) if seo_metadata_params.present?
      redirect_to admin_cms_page_path(@page), notice: 'Page was successfully updated.'
    else
      set_breadcrumbs('Pages', @page.title, 'Edit')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @page.destroy
    redirect_to admin_cms_pages_path, notice: 'Page was successfully deleted.'
  end

  def publish
    @page.update!(published: true, published_at: Time.current)
    redirect_to admin_cms_page_path(@page), notice: 'Page was successfully published.'
  end

  def unpublish
    @page.update!(published: false, published_at: nil)
    redirect_to admin_cms_page_path(@page), notice: 'Page was successfully unpublished.'
  end

  private

  def set_page
    @page = Page.friendly.find(params[:id])
  end

  def page_params
    params.require(:page).permit(
      :title, :content, :excerpt, :published, :template_name, :sort_order
    )
  end

  def seo_metadata_params
    return {} unless params[:page][:seo_metadata_attributes]
    
    params.require(:page)[:seo_metadata_attributes].permit(
      :meta_title, :meta_description, :meta_keywords, :canonical_url,
      :og_title, :og_description, :og_image_url, :og_type,
      :index_page, :follow_links
    )
  end
end