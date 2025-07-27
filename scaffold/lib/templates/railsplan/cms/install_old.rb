# frozen_string_literal: true

# Synth CMS module installer for the Rails SaaS starter template.
# This install script sets up a complete CMS/blog engine with ActionText,
# WYSIWYG editing, SEO metadata, and sitemap generation.

say_status :railsplan_cms, "Installing CMS/Blog Engine module"

# Create domain-specific directories
run 'mkdir -p app/domains/cms/app/{controllers/cms,controllers/admin,views/cms/posts,views/cms/pages,views/admin/posts,views/admin/pages,views/admin/categories,views/admin/tags,views/layouts}'
run 'mkdir -p app/models' # Ensure models directory exists
run 'mkdir -p spec/domains/cms/{models,controllers,fixtures}'

# Add required gems to the application's Gemfile
gem 'friendly_id', '~> 5.5'
gem 'meta-tags', '~> 2.19'
gem 'image_processing', '~> 1.12'
gem 'kaminari', '~> 1.2'

# Development gems for better admin experience
gem_group :development do
  gem 'rails_real_favicons', '~> 0.0.7'
end

# Run bundle install and set up CMS after gems are installed
after_bundle do
  # Install ActionText if not already installed
  unless File.exist?('db/migrate/*_create_action_text_tables.rb')
    rails_command 'action_text:install'
  end

  # Install Active Storage if not already installed
  unless File.exist?('db/migrate/*_create_active_storage_tables.rb')
    rails_command 'active_storage:install'
  end

  # Generate FriendlyId configuration
  generate 'friendly_id'

  # Create CMS configuration initializer
  initializer 'cms.rb', <<~'RUBY'
    # CMS module configuration
    Rails.application.config.cms = ActiveSupport::OrderedOptions.new

    # Pagination settings
    Rails.application.config.cms.per_page = 10
    Rails.application.config.cms.admin_per_page = 20

    # Caching settings
    Rails.application.config.cms.cache_expires_in = 1.hour
    Rails.application.config.cms.enable_caching = Rails.env.production?

    # SEO settings
    Rails.application.config.cms.sitemap_enabled = true
    Rails.application.config.cms.default_meta_title = "Your Site"
    Rails.application.config.cms.default_meta_description = "Welcome to our site"

    # Upload settings
    Rails.application.config.cms.max_file_size = 10.megabytes
    Rails.application.config.cms.allowed_file_types = %w[jpg jpeg png gif pdf doc docx]
  RUBY

  # Generate CMS models
  generate :model, 'Cms::Category', 
           'name:string:index', 
           'slug:string:uniq', 
           'description:text',
           'meta_title:string',
           'meta_description:text',
           'parent:references',
           'position:integer',
           'published:boolean:index'

  generate :model, 'Cms::Tag',
           'name:string:index',
           'slug:string:uniq',
           'description:text',
           'color:string'

  generate :model, 'Cms::Post',
           'title:string:index',
           'slug:string:uniq',
           'excerpt:text',
           'meta_title:string',
           'meta_description:text',
           'meta_keywords:string',
           'published:boolean:index',
           'featured:boolean:index',
           'published_at:datetime:index',
           'author:references',
           'category:references',
           'view_count:integer:index'

  generate :model, 'Cms::Page',
           'title:string:index',
           'slug:string:uniq',
           'meta_title:string',
           'meta_description:text',
           'meta_keywords:string',
           'published:boolean:index',
           'template:string',
           'position:integer'

  # Generate join table for posts and tags
  generate :migration, 'CreateCmsPostsTags', 'post:references', 'tag:references'

  # Create CMS controllers directory
  run 'mkdir -p app/controllers/cms'
  run 'mkdir -p app/controllers/admin'

  # Generate admin controllers
  create_file 'app/domains/cms/app/controllers/admin/cms_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::CmsController < ApplicationController
      before_action :authenticate_user!
      before_action :ensure_admin!
      layout 'admin'

      protected

      def ensure_admin!
        redirect_to root_path unless current_user.respond_to?(:admin?) && current_user.admin?
      end
    end
  RUBY

  create_file 'app/domains/cms/app/controllers/admin/posts_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::PostsController < Admin::CmsController
      before_action :set_post, only: [:show, :edit, :update, :destroy]

      def index
        @posts = Cms::Post.includes(:author, :category, :tags)
                          .page(params[:page])
                          .per(Rails.application.config.cms.admin_per_page)
        @posts = @posts.where(published: params[:published]) if params[:published].present?
      end

      def show
      end

      def new
        @post = Cms::Post.new
      end

      def create
        @post = Cms::Post.new(post_params)
        @post.author = current_user

        if @post.save
          redirect_to admin_post_path(@post), notice: 'Post created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @post.update(post_params)
          redirect_to admin_post_path(@post), notice: 'Post updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @post.destroy
        redirect_to admin_posts_path, notice: 'Post deleted successfully.'
      end

      private

      def set_post
        @post = Cms::Post.friendly.find(params[:id])
      end

      def post_params
        params.require(:cms_post).permit(:title, :excerpt, :content, :meta_title, 
                                         :meta_description, :meta_keywords, :published, 
                                         :featured, :published_at, :category_id, tag_ids: [])
      end
    end
  RUBY

  create_file 'app/domains/cms/app/controllers/admin/pages_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::PagesController < Admin::CmsController
      before_action :set_page, only: [:show, :edit, :update, :destroy]

      def index
        @pages = Cms::Page.page(params[:page])
                          .per(Rails.application.config.cms.admin_per_page)
      end

      def show
      end

      def new
        @page = Cms::Page.new
      end

      def create
        @page = Cms::Page.new(page_params)

        if @page.save
          redirect_to admin_page_path(@page), notice: 'Page created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @page.update(page_params)
          redirect_to admin_page_path(@page), notice: 'Page updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @page.destroy
        redirect_to admin_pages_path, notice: 'Page deleted successfully.'
      end

      private

      def set_page
        @page = Cms::Page.friendly.find(params[:id])
      end

      def page_params
        params.require(:cms_page).permit(:title, :content, :meta_title, 
                                         :meta_description, :meta_keywords, 
                                         :published, :template, :position)
      end
    end
  RUBY

  create_file 'app/domains/cms/app/controllers/admin/categories_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::CategoriesController < Admin::CmsController
      before_action :set_category, only: [:show, :edit, :update, :destroy]

      def index
        @categories = Cms::Category.includes(:parent, :children)
                                   .page(params[:page])
                                   .per(Rails.application.config.cms.admin_per_page)
      end

      def show
      end

      def new
        @category = Cms::Category.new
      end

      def create
        @category = Cms::Category.new(category_params)

        if @category.save
          redirect_to admin_category_path(@category), notice: 'Category created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @category.update(category_params)
          redirect_to admin_category_path(@category), notice: 'Category updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @category.destroy
        redirect_to admin_categories_path, notice: 'Category deleted successfully.'
      end

      private

      def set_category
        @category = Cms::Category.friendly.find(params[:id])
      end

      def category_params
        params.require(:cms_category).permit(:name, :description, :meta_title, 
                                             :meta_description, :parent_id, 
                                             :position, :published)
      end
    end
  RUBY

  create_file 'app/domains/cms/app/controllers/admin/tags_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Admin::TagsController < Admin::CmsController
      before_action :set_tag, only: [:show, :edit, :update, :destroy]

      def index
        @tags = Cms::Tag.page(params[:page])
                        .per(Rails.application.config.cms.admin_per_page)
      end

      def show
      end

      def new
        @tag = Cms::Tag.new
      end

      def create
        @tag = Cms::Tag.new(tag_params)

        if @tag.save
          redirect_to admin_tag_path(@tag), notice: 'Tag created successfully.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @tag.update(tag_params)
          redirect_to admin_tag_path(@tag), notice: 'Tag updated successfully.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @tag.destroy
        redirect_to admin_tags_path, notice: 'Tag deleted successfully.'
      end

      private

      def set_tag
        @tag = Cms::Tag.friendly.find(params[:id])
      end

      def tag_params
        params.require(:cms_tag).permit(:name, :description, :color)
      end
    end
  RUBY

  # Generate public controllers
  create_file 'app/domains/cms/app/controllers/cms/posts_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Cms::PostsController < ApplicationController
      before_action :set_post, only: [:show]
      before_action :set_meta_tags

      def index
        @posts = Cms::Post.published
                          .includes(:author, :category, :tags)
                          .order(published_at: :desc)
                          .page(params[:page])
                          .per(Rails.application.config.cms.per_page)

        if params[:category].present?
          @category = Cms::Category.friendly.find(params[:category])
          @posts = @posts.where(category: @category)
        end

        if params[:tag].present?
          @tag = Cms::Tag.friendly.find(params[:tag])
          @posts = @posts.joins(:tags).where(cms_tags: { id: @tag.id })
        end
      end

      def show
        @post.increment!(:view_count)
        
        set_meta_tags(
          title: @post.meta_title.presence || @post.title,
          description: @post.meta_description.presence || @post.excerpt,
          keywords: @post.meta_keywords
        )
      end

      private

      def set_post
        @post = Cms::Post.published.friendly.find(params[:id])
      end

      def set_meta_tags
        set_meta_tags(
          title: Rails.application.config.cms.default_meta_title,
          description: Rails.application.config.cms.default_meta_description
        )
      end
    end
  RUBY

  create_file 'app/domains/cms/app/controllers/cms/pages_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Cms::PagesController < ApplicationController
      before_action :set_page, only: [:show]

      def show
        set_meta_tags(
          title: @page.meta_title.presence || @page.title,
          description: @page.meta_description,
          keywords: @page.meta_keywords
        )

        if @page.template.present?
          render template: "cms/pages/templates/#{@page.template}"
        else
          render :show
        end
      end

      private

      def set_page
        @page = Cms::Page.published.friendly.find(params[:id])
      end
    end
  RUBY

  # Generate sitemap controller
  create_file 'app/domains/cms/app/controllers/sitemaps_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class SitemapsController < ApplicationController
      def show
        @posts = Cms::Post.published.includes(:category)
        @pages = Cms::Page.published
        @categories = Cms::Category.published

        respond_to do |format|
          format.xml { render layout: false }
        end
      end
    end
  RUBY

  # Add CMS routes
  route <<~'RUBY'
    scope module: :cms do
      # CMS routes
      namespace :cms do
        resources :posts, only: [:index, :show], path: 'blog'
        resources :pages, only: [:show], path: ''
      end

      # Admin CMS routes
      namespace :admin do
        resources :posts, :pages, :categories, :tags
        get 'cms', to: 'posts#index'
      end

      # SEO routes
      get 'sitemap.xml', to: 'sitemaps#show', defaults: { format: 'xml' }
      get 'blog', to: 'cms/posts#index'
      get 'blog/category/:category', to: 'cms/posts#index', as: :blog_category
      get 'blog/tag/:tag', to: 'cms/posts#index', as: :blog_tag
    end
  RUBY

  say_status :railsplan_cms, "Generated models, controllers, and routes"

  # Create model concerns and update models
  run 'mkdir -p app/models/concerns'
  
  create_file 'app/models/concerns/seo_meta.rb', <<~'RUBY'
    # frozen_string_literal: true

    module SeoMeta
      extend ActiveSupport::Concern

      def seo_title
        meta_title.presence || title
      end

      def seo_description
        meta_description.presence || try(:excerpt)
      end

      def seo_keywords
        meta_keywords.presence || try(:tag_list)
      end
    end
  RUBY

  # Update generated models
  gsub_file 'app/models/cms/category.rb', /class Cms::Category.*/, <<~'RUBY'
    class Cms::Category < ApplicationRecord
      include SeoMeta
      
      extend FriendlyId
      friendly_id :name, use: :slugged

      belongs_to :parent, class_name: 'Cms::Category', optional: true
      has_many :children, class_name: 'Cms::Category', foreign_key: 'parent_id', dependent: :destroy
      has_many :posts, class_name: 'Cms::Post', foreign_key: 'category_id', dependent: :nullify

      validates :name, presence: true, uniqueness: true
      validates :slug, presence: true, uniqueness: true

      scope :published, -> { where(published: true) }
      scope :ordered, -> { order(:position, :name) }
      scope :roots, -> { where(parent_id: nil) }

      def should_generate_new_friendly_id?
        name_changed? || super
      end

      def to_param
        slug
      end
    end
  RUBY

  gsub_file 'app/models/cms/tag.rb', /class Cms::Tag.*/, <<~'RUBY'
    class Cms::Tag < ApplicationRecord
      extend FriendlyId
      friendly_id :name, use: :slugged

      has_and_belongs_to_many :posts, class_name: 'Cms::Post', join_table: 'cms_posts_tags'

      validates :name, presence: true, uniqueness: true
      validates :slug, presence: true, uniqueness: true

      scope :ordered, -> { order(:name) }

      def should_generate_new_friendly_id?
        name_changed? || super
      end

      def to_param
        slug
      end
    end
  RUBY

  gsub_file 'app/models/cms/post.rb', /class Cms::Post.*/, <<~'RUBY'
    class Cms::Post < ApplicationRecord
      include SeoMeta
      
      extend FriendlyId
      friendly_id :title, use: :slugged

      has_rich_text :content
      has_one_attached :featured_image

      belongs_to :author, class_name: 'User'
      belongs_to :category, class_name: 'Cms::Category', optional: true
      has_and_belongs_to_many :tags, class_name: 'Cms::Tag', join_table: 'cms_posts_tags'

      validates :title, presence: true
      validates :slug, presence: true, uniqueness: true
      validates :content, presence: true

      scope :published, -> { where(published: true) }
      scope :featured, -> { where(featured: true) }
      scope :by_date, -> { order(published_at: :desc, created_at: :desc) }

      before_validation :set_published_at, if: :will_save_change_to_published?

      def should_generate_new_friendly_id?
        title_changed? || super
      end

      def to_param
        slug
      end

      def published?
        published && published_at&.<= Time.current
      end

      def tag_list
        tags.pluck(:name).join(', ')
      end

      private

      def set_published_at
        self.published_at = published? ? (published_at || Time.current) : nil
      end
    end
  RUBY

  gsub_file 'app/models/cms/page.rb', /class Cms::Page.*/, <<~'RUBY'
    class Cms::Page < ApplicationRecord
      include SeoMeta
      
      extend FriendlyId
      friendly_id :title, use: :slugged

      has_rich_text :content
      has_one_attached :featured_image

      validates :title, presence: true
      validates :slug, presence: true, uniqueness: true
      validates :content, presence: true

      scope :published, -> { where(published: true) }
      scope :ordered, -> { order(:position, :title) }

      def should_generate_new_friendly_id?
        title_changed? || super
      end

      def to_param
        slug
      end
    end
  RUBY

  # Update the join table migration
  migration_file = Dir.glob('db/migrate/*_create_cms_posts_tags.rb').first
  if migration_file
    gsub_file migration_file, /def change.*?end/m, <<~'RUBY'
      def change
        create_join_table :cms_posts, :cms_tags do |t|
          t.index [:cms_post_id, :cms_tag_id], unique: true
          t.index [:cms_tag_id, :cms_post_id], unique: true
        end
      end
    RUBY
  end

  say_status :railsplan_cms, "Updated models with associations and validations"

  # Generate views directory structure
  run 'mkdir -p app/domains/cms/app/views/cms/posts'
  run 'mkdir -p app/domains/cms/app/views/cms/pages'
  run 'mkdir -p app/domains/cms/app/views/admin/posts'
  run 'mkdir -p app/domains/cms/app/views/admin/pages'
  run 'mkdir -p app/domains/cms/app/views/admin/categories'
  run 'mkdir -p app/domains/cms/app/views/admin/tags'
  run 'mkdir -p app/domains/cms/app/views/layouts'
  run 'mkdir -p app/domains/cms/app/views/sitemaps'

  # Load view templates
  require_relative 'views'

  # Create admin layout
  create_file 'app/domains/cms/app/views/layouts/admin.html.erb', CmsViews::ADMIN_LAYOUT

  # Create admin views
  create_file 'app/domains/cms/app/views/admin/posts/index.html.erb', CmsViews::POSTS_INDEX
  create_file 'app/domains/cms/app/views/admin/posts/_form.html.erb', CmsViews::POST_FORM
  create_file 'app/domains/cms/app/views/admin/posts/new.html.erb', <<~'ERB'
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          New Post
        </h2>
      </div>
    </div>

    <%= render 'form', post: @post %>
  ERB

  create_file 'app/domains/cms/app/views/admin/posts/edit.html.erb', <<~'ERB'
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          Edit Post
        </h2>
      </div>
      <div class="mt-4 flex md:ml-4 md:mt-0">
        <%= link_to "View Post", cms_post_path(@post), 
            class: "inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50",
            target: "_blank" %>
      </div>
    </div>

    <%= render 'form', post: @post %>
  ERB

  create_file 'app/domains/cms/app/views/admin/posts/show.html.erb', <<~'ERB'
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          <%= @post.title %>
        </h2>
        <div class="mt-1 flex flex-col sm:mt-0 sm:flex-row sm:flex-wrap sm:space-x-6">
          <div class="mt-2 flex items-center text-sm text-gray-500">
            Status: 
            <% if @post.published? %>
              <span class="ml-1 inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Published</span>
            <% else %>
              <span class="ml-1 inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">Draft</span>
            <% end %>
          </div>
          <div class="mt-2 flex items-center text-sm text-gray-500">
            Published: <%= @post.published_at&.strftime("%B %d, %Y at %I:%M %p") || "Not published" %>
          </div>
        </div>
      </div>
      <div class="mt-4 flex md:ml-4 md:mt-0">
        <%= link_to "Edit", edit_admin_post_path(@post), 
            class: "inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500" %>
        <%= link_to "View Post", cms_post_path(@post), 
            class: "ml-3 inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50",
            target: "_blank" %>
      </div>
    </div>

    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="prose prose-lg max-w-none">
          <%= @post.content %>
        </div>
      </div>
    </div>
  ERB

  # Create public views
  create_file 'app/domains/cms/app/views/cms/posts/index.html.erb', CmsViews::BLOG_INDEX
  create_file 'app/domains/cms/app/views/cms/posts/show.html.erb', CmsViews::BLOG_POST

  # Create sitemap view
  create_file 'app/domains/cms/app/views/sitemaps/show.xml.erb', CmsViews::SITEMAP_XML

  # Create basic page views (similar structure to posts)
  create_file 'app/domains/cms/app/views/admin/pages/index.html.erb', <<~'ERB'
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <h1 class="text-base font-semibold leading-6 text-gray-900">Pages</h1>
        <p class="mt-2 text-sm text-gray-700">Manage your static pages.</p>
      </div>
      <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
        <%= link_to "New Page", new_admin_page_path, 
            class: "block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500" %>
      </div>
    </div>

    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0">Title</th>
                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Template</th>
                <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <% @pages.each do |page| %>
                <tr>
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-0">
                    <%= link_to page.title, admin_page_path(page), class: "text-indigo-600 hover:text-indigo-900" %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <% if page.published? %>
                      <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Published</span>
                    <% else %>
                      <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">Draft</span>
                    <% end %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <%= page.template || "Default" %>
                  </td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                    <%= link_to "Edit", edit_admin_page_path(page), class: "text-indigo-600 hover:text-indigo-900" %>
                    <%= link_to "Delete", admin_page_path(page), method: :delete, 
                        data: { confirm: "Are you sure?" }, 
                        class: "ml-2 text-red-600 hover:text-red-900" %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <%= paginate @pages if respond_to?(:paginate) %>
  ERB

  # Similar forms for pages (reusing post form structure)
  create_file 'app/domains/cms/app/views/admin/pages/_form.html.erb', <<~'ERB'
    <%= form_with(model: [:admin, @page], local: true, class: "space-y-6") do |form| %>
      <% if @page.errors.any? %>
        <div class="rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">
                <%= pluralize(@page.errors.count, "error") %> prohibited this page from being saved:
              </h3>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc space-y-1 pl-5">
                  <% @page.errors.full_messages.each do |message| %>
                    <li><%= message %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div>
        <%= form.label :title, class: "block text-sm font-medium leading-6 text-gray-900" %>
        <%= form.text_field :title, 
            class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
      </div>

      <div>
        <%= form.label :content, class: "block text-sm font-medium leading-6 text-gray-900" %>
        <%= form.rich_text_area :content, class: "mt-2" %>
      </div>

      <div class="grid grid-cols-1 gap-x-6 gap-y-6 sm:grid-cols-2">
        <div>
          <%= form.label :template, class: "block text-sm font-medium leading-6 text-gray-900" %>
          <%= form.text_field :template, 
              class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          <p class="mt-2 text-sm text-gray-500">Optional custom template name</p>
        </div>

        <div>
          <%= form.label :position, class: "block text-sm font-medium leading-6 text-gray-900" %>
          <%= form.number_field :position, 
              class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
        </div>
      </div>

      <!-- SEO Fields -->
      <div class="border-t border-gray-200 pt-6">
        <h3 class="text-lg font-medium leading-6 text-gray-900">SEO Settings</h3>
        
        <div class="mt-6 space-y-6">
          <div>
            <%= form.label :meta_title, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_field :meta_title, 
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          </div>

          <div>
            <%= form.label :meta_description, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_area :meta_description, rows: 3,
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          </div>

          <div>
            <%= form.label :meta_keywords, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_field :meta_keywords, 
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
            <p class="mt-2 text-sm text-gray-500">Separate keywords with commas</p>
          </div>
        </div>
      </div>

      <!-- Publishing Options -->
      <div class="border-t border-gray-200 pt-6">
        <h3 class="text-lg font-medium leading-6 text-gray-900">Publishing</h3>
        
        <div class="mt-6 space-y-6">
          <div class="flex items-center">
            <%= form.check_box :published, class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600" %>
            <%= form.label :published, "Published", class: "ml-3 text-sm font-medium text-gray-700" %>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end gap-x-6">
        <%= link_to "Cancel", admin_pages_path, 
            class: "text-sm font-semibold leading-6 text-gray-900" %>
        <%= form.submit class: "rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600" %>
      </div>
    <% end %>
  ERB

  create_file 'app/domains/cms/app/views/admin/pages/new.html.erb', <<~'ERB'
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          New Page
        </h2>
      </div>
    </div>

    <%= render 'form', page: @page %>
  ERB

  create_file 'app/domains/cms/app/views/admin/pages/edit.html.erb', <<~'ERB'
    <div class="md:flex md:items-center md:justify-between mb-8">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          Edit Page
        </h2>
      </div>
      <div class="mt-4 flex md:ml-4 md:mt-0">
        <%= link_to "View Page", cms_page_path(@page), 
            class: "inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50",
            target: "_blank" %>
      </div>
    </div>

    <%= render 'form', page: @page %>
  ERB

  create_file 'app/domains/cms/app/views/cms/pages/show.html.erb', <<~'ERB'
    <article class="mx-auto max-w-3xl px-6 py-24 lg:px-8">
      <div class="mx-auto max-w-2xl lg:mx-0">
        <h1 class="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
          <%= @page.title %>
        </h1>
      </div>

      <div class="mx-auto mt-10 max-w-2xl lg:mx-0 lg:max-w-none">
        <div class="prose prose-lg prose-gray max-w-none">
          <%= @page.content %>
        </div>
      </div>
    </article>
  ERB

  say_status :railsplan_cms, "Generated view templates"

  say_status :railsplan_cms, "CMS module installed successfully!"
  say_status :railsplan_cms, "Next steps:"
  say_status :railsplan_cms, "1. Run: rails db:migrate"
  say_status :railsplan_cms, "2. Add admin? method to User model"
  say_status :railsplan_cms, "3. Configure Active Storage for file uploads"
  say_status :railsplan_cms, "4. Visit /admin/cms to start creating content"
end