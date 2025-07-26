# frozen_string_literal: true

class Admin::Cms::DashboardController < Admin::Cms::BaseController
  def index
    set_breadcrumbs

    @stats = {
      total_posts: Post.count,
      published_posts: Post.published.count,
      draft_posts: Post.unpublished.count,
      total_pages: Page.count,
      published_pages: Page.published.count,
      draft_pages: Page.unpublished.count,
      categories: Category.count,
      tags: Tag.count
    }

    @recent_posts = Post.includes(:author, :category)
                       .order(created_at: :desc)
                       .limit(5)

    @recent_pages = Page.includes(:author)
                       .order(created_at: :desc)
                       .limit(5)

    @popular_posts = Post.published
                        .order(view_count: :desc)
                        .limit(5)

    @popular_categories = Category.joins(:posts)
                                 .where(posts: { published: true })
                                 .select('categories.*, COUNT(posts.id) as posts_count')
                                 .group('categories.id')
                                 .order('posts_count DESC')
                                 .limit(5)
  end
end