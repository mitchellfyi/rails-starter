# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :set_page, only: [:show]

  def show
    unless @page.published?
      raise ActiveRecord::RecordNotFound
    end

    respond_to do |format|
      format.html { render template: "pages/show", layout: layout_for_page }
      format.json { render json: @page, include: [:author, :seo_metadata] }
    end
  end

  private

  def set_page
    @page = Page.friendly.find(params[:slug])
  end

  def layout_for_page
    case @page.template_name
    when 'full_width'
      'application_full_width'
    when 'landing'
      'application_landing'
    else
      'application'
    end
  rescue
    'application'
  end
end