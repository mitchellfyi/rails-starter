# frozen_string_literal: true

# CMS module main installer

say_status :railsplan_cms, "Installing CMS/Blog Engine module"

# Add CMS gems
gem 'image_processing', '~> 1.2'
gem 'friendly_id', '~> 5.5'
gem 'meta-tags', '~> 2.20'

after_bundle do
  # Create directory structure
  run 'mkdir -p app/domains/cms/app/controllers/cms'
  run 'mkdir -p app/domains/cms/app/models'
  run 'mkdir -p app/domains/cms/app/views/cms'
  run 'mkdir -p app/domains/cms/app/helpers'
  
  # Create CMS configuration
  initializer 'cms.rb', <<~'RUBY'
    # CMS module configuration
    Rails.application.config.cms = ActiveSupport::OrderedOptions.new
    
    # Blog settings
    Rails.application.config.cms.posts_per_page = 10
    Rails.application.config.cms.allow_comments = true
    Rails.application.config.cms.require_approval = true
    
    # SEO settings
    Rails.application.config.cms.auto_generate_sitemap = true
    Rails.application.config.cms.meta_description_length = 160
  RUBY
  
  # Generate models
  generate "model", "Post", "title:string", "slug:string", "content:text", "excerpt:text", "published:boolean", "published_at:datetime", "user:references"
  generate "model", "Category", "name:string", "slug:string", "description:text"
  generate "model", "PostCategory", "post:references", "category:references"
  
  # Copy application files
  directory 'app', 'app/domains/cms/app', force: true
  
  # Add routes
  route <<~RUBY
    # CMS module routes
    namespace :cms do
      resources :posts do
        member do
          patch :publish
          patch :unpublish
        end
      end
      resources :categories
    end
    
    # Public blog routes
    scope :blog do
      resources :posts, only: [:index, :show], controller: 'cms/public/posts'
      resources :categories, only: [:index, :show], controller: 'cms/public/categories', path: 'category'
    end
  RUBY
  
  say_status :railsplan_cms, "✅ CMS/Blog Engine module installed successfully!"
  say_status :railsplan_cms, "📝 Run 'rails db:migrate' to apply CMS database changes"
  say_status :railsplan_cms, "📖 Access CMS admin at /cms/"
  say_status :railsplan_cms, "🌐 Public blog available at /blog/"
end