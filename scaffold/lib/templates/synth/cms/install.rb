# frozen_string_literal: true

# Synth CMS module installer for the Rails SaaS starter template.

say_status :synth_cms, "Installing CMS module"

# Add CMS specific gems to the application's Gemfile
add_gem 'image_processing' # For ActiveStorage image variants
add_gem 'friendly_id' # For SEO-friendly URLs

# Run bundle install and set up CMS configuration after gems are installed
after_bundle do
  # Generate models for CMS
  say_status :synth_cms, "Generating CMS models and migrations"
  
  # Post model for blog posts
  generate :model, 'Post',
    'title:string',
    'slug:string:index',
    'excerpt:text',
    'content:text',
    'status:string:index', # draft, published, scheduled, archived
    'published_at:datetime',
    'author:references',
    'workspace:references',
    'tags:text', # JSON array
    'meta_title:string',
    'meta_description:text',
    'featured_image_url:string',
    'featured:boolean',
    'reading_time_minutes:integer',
    'view_count:integer'
    
  # Category model (optional)
  generate :model, 'Category',
    'name:string',
    'slug:string:index',
    'description:text',
    'color:string'
    
  # Comment model (optional)
  generate :model, 'Comment',
    'post:references',
    'author:references',
    'content:text',
    'status:string:index', # pending, approved, spam
    'parent:references'
    
  # Tag model (if tags need to be separate entities)
  generate :model, 'Tag',
    'name:string',
    'slug:string:index',
    'color:string',
    'posts_count:integer'
    
  # Newsletter subscription model
  generate :model, 'NewsletterSubscription',
    'email:string:index',
    'status:string:index', # active, unsubscribed, bounced
    'subscribed_at:datetime',
    'confirmed_at:datetime',
    'unsubscribed_at:datetime'

  # Add indexes and constraints
  create_file 'db/migrate/add_cms_indexes.rb', <<~RUBY
    class AddCmsIndexes < ActiveRecord::Migration[7.1]
      def change
        add_index :posts, [:workspace_id, :status]
        add_index :posts, [:author_id, :created_at]
        add_index :posts, [:published_at, :status]
        add_index :posts, :featured
        add_index :categories, :slug, unique: true
        add_index :comments, [:post_id, :status]
        add_index :tags, :slug, unique: true
        add_index :newsletter_subscriptions, :email, unique: true
        add_index :newsletter_subscriptions, :status
      end
    end
  RUBY

  # Add FriendlyId initializer
  generate 'friendly_id'

  # Create CMS routes
  route <<~ROUTES
    # CMS routes
    resources :posts, only: [:index, :show] do
      resources :comments, only: [:create]
    end
    resources :categories, only: [:index, :show]
    resources :tags, only: [:index, :show]
    resources :newsletter_subscriptions, only: [:create, :destroy]
  ROUTES

  say_status :synth_cms, "CMS module installed. Please run migrations."
  say_status :synth_cms, "Run 'rails db:seed' to create example blog posts and categories."
end