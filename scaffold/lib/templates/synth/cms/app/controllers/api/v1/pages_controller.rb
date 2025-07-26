# frozen_string_literal: true

class Api::V1::PagesController < Api::V1::BaseController
  before_action :set_page, only: [:show]

  def index
    @pages = Page.published
                 .includes(:author, :seo_metadata)
                 .ordered
                 .page(params[:page])
                 .per(params[:per_page] || 20)

    render json: @pages, include: [:author], meta: pagination_meta(@pages)
  end

  def show
    render json: @page, include: [:author, :seo_metadata]
  end

  private

  def set_page
    @page = Page.friendly.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @page.published?
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