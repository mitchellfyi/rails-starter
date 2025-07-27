# frozen_string_literal: true

class SitemapsController < ApplicationController
  def show
    @posts = Post.published.includes(:seo_metadata).order(:updated_at)
    @pages = Page.published.includes(:seo_metadata).order(:updated_at)
    @categories = Category.joins(:posts).where(posts: { published: true }).distinct
    @tags = Tag.joins(:posts).where(posts: { published: true }).distinct

    respond_to do |format|
      format.xml { render layout: false }
    end
  end
end