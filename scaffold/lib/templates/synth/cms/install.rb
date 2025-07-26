# frozen_string_literal: true

# Synth CMS module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the CMS module.
# It sets up a comprehensive content management system with ActionText, SEO optimization,
# and blog/page functionality.

say_status :synth_cms, "Installing CMS module with ActionText and SEO optimization"

# Add CMS specific gems to the application's Gemfile
gem 'friendly_id', '~> 5.5'
gem 'image_processing', '~> 1.13' if !File.read('Gemfile').include?('image_processing')

# Run bundle install and set up CMS configuration after gems are installed
after_bundle do
  # Create an initializer for CMS configuration
  initializer 'cms.rb', <<~'RUBY'
    # CMS module configuration
    Rails.application.config.cms = ActiveSupport::OrderedOptions.new
    Rails.application.config.cms.default_meta_description = "A Rails SaaS application"
    Rails.application.config.cms.sitemap_host = ENV.fetch('SITEMAP_HOST', 'http://localhost:3000')
    Rails.application.config.cms.posts_per_page = 10
    Rails.application.config.cms.pages_per_page = 20
    Rails.application.config.cms.enable_caching = Rails.env.production?
  RUBY

  # Install ActionText if not already present
  rails_command 'action_text:install' unless File.exist?('app/models/concerns/action_text_content.rb')

  # Create CMS models
  directory 'app', 'app'
  directory 'config', 'config'
  directory 'db', 'db'
  directory 'test', 'test'

  # Add routes to the application
  route <<~'RUBY'
    # CMS public routes
    get '/blog', to: 'blog#index'
    get '/blog/category/:slug', to: 'blog#category', as: 'blog_category'
    get '/blog/tag/:slug', to: 'blog#tag', as: 'blog_tag'
    get '/blog/:slug', to: 'blog#show', as: 'blog_post'
    get '/sitemap.xml', to: 'sitemaps#show', defaults: { format: 'xml' }
    
    # Static pages route
    get '/:slug', to: 'pages#show', as: 'page', constraints: { slug: /(?!admin|api|blog).*/ }

    # Admin CMS routes
    namespace :admin do
      namespace :cms do
        root 'dashboard#index'
        resources :posts do
          member do
            patch :publish
            patch :unpublish
          end
        end
        resources :pages do
          member do
            patch :publish
            patch :unpublish
          end
        end
        resources :categories
        resources :tags
        resources :seo_metadata, only: [:show, :edit, :update]
      end
    end

    # API routes for programmatic access
    namespace :api do
      namespace :v1 do
        resources :posts, only: [:index, :show] do
          collection do
            get :published
            get :recent
          end
        end
        resources :pages, only: [:index, :show]
        resources :categories, only: [:index, :show]
        resources :tags, only: [:index, :show]
      end
    end
  RUBY

  # Create migration for CMS tables
  migration_template = <<~'RUBY'
    class CreateCmsTables < ActiveRecord::Migration[7.0]
      def change
        create_table :categories do |t|
          t.string :name, null: false
          t.string :slug, null: false
          t.text :description
          t.references :parent, null: true, foreign_key: { to_table: :categories }
          t.integer :sort_order, default: 0
          t.timestamps
        end

        create_table :tags do |t|
          t.string :name, null: false
          t.string :slug, null: false
          t.text :description
          t.string :color, default: '#3B82F6'
          t.timestamps
        end

        create_table :posts do |t|
          t.string :title, null: false
          t.string :slug, null: false
          t.text :excerpt
          t.references :category, null: true, foreign_key: true
          t.references :author, null: false, foreign_key: { to_table: :users }
          t.boolean :published, default: false
          t.datetime :published_at
          t.integer :view_count, default: 0
          t.boolean :featured, default: false
          t.integer :reading_time # in minutes
          t.timestamps
        end

        create_table :pages do |t|
          t.string :title, null: false
          t.string :slug, null: false
          t.text :excerpt
          t.references :author, null: false, foreign_key: { to_table: :users }
          t.boolean :published, default: false
          t.datetime :published_at
          t.string :template_name, default: 'default'
          t.integer :sort_order, default: 0
          t.timestamps
        end

        create_table :post_tags do |t|
          t.references :post, null: false, foreign_key: true
          t.references :tag, null: false, foreign_key: true
          t.timestamps
        end

        create_table :seo_metadata do |t|
          t.references :seo_optimizable, polymorphic: true, null: false
          t.string :meta_title, limit: 60
          t.text :meta_description, limit: 160
          t.string :meta_keywords
          t.string :canonical_url
          t.string :og_title
          t.text :og_description
          t.string :og_image_url
          t.string :og_type, default: 'website'
          t.boolean :index_page, default: true
          t.boolean :follow_links, default: true
          t.timestamps
        end

        # Add indexes for performance
        add_index :categories, :slug, unique: true
        add_index :categories, :parent_id
        add_index :tags, :slug, unique: true
        add_index :posts, :slug, unique: true
        add_index :posts, [:published, :published_at]
        add_index :posts, :category_id
        add_index :posts, :author_id
        add_index :pages, :slug, unique: true
        add_index :pages, [:published, :published_at]
        add_index :pages, :author_id
        add_index :post_tags, [:post_id, :tag_id], unique: true
        add_index :seo_metadata, [:seo_optimizable_type, :seo_optimizable_id], 
                  name: 'index_seo_metadata_on_optimizable'
        
        # Add full-text search indexes for PostgreSQL
        add_index :posts, :title, using: :gin, opclass: { title: :gin_trgm_ops }
        add_index :posts, :excerpt, using: :gin, opclass: { excerpt: :gin_trgm_ops }
        add_index :pages, :title, using: :gin, opclass: { title: :gin_trgm_ops }
      end
    end
  RUBY

  timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{timestamp}_create_cms_tables.rb", migration_template

  # Create FriendlyId configuration
  rails_command 'generate friendly_id'

  # Run migrations
  rails_command 'db:migrate'

  # Create seed data
  create_file 'db/seeds/cms_seeds.rb', <<~'RUBY'
    # frozen_string_literal: true

    # Create sample CMS content

    # Create categories
    unless Category.exists?
      puts "Creating sample categories..."

      Category.create!([
        {
          name: "Tutorials",
          description: "Step-by-step guides and tutorials"
        },
        {
          name: "News",
          description: "Latest news and updates"
        },
        {
          name: "Product Updates",
          description: "New features and improvements"
        },
        {
          name: "Company",
          description: "Company news and announcements"
        }
      ])

      puts "Created #{Category.count} categories."
    end

    # Create tags
    unless Tag.exists?
      puts "Creating sample tags..."

      Tag.create!([
        { name: "Rails", color: "#DC2626" },
        { name: "Ruby", color: "#DC2626" },
        { name: "JavaScript", color: "#F59E0B" },
        { name: "TailwindCSS", color: "#06B6D4" },
        { name: "Tutorial", color: "#10B981" },
        { name: "Tips", color: "#8B5CF6" },
        { name: "Best Practices", color: "#EC4899" }
      ])

      puts "Created #{Tag.count} tags."
    end

    # Create sample user if needed
    user = User.first || User.create!(
      email: 'admin@example.com',
      password: 'password123',
      name: 'Admin User',
      admin: true
    )

    # Create sample blog posts
    unless Post.exists?
      puts "Creating sample blog posts..."

      tutorials_category = Category.find_by(name: "Tutorials")
      rails_tag = Tag.find_by(name: "Rails")
      tutorial_tag = Tag.find_by(name: "Tutorial")

      post = Post.create!(
        title: "Getting Started with Rails SaaS Development",
        excerpt: "Learn how to build a modern SaaS application with Ruby on Rails, including authentication, billing, and more.",
        content: <<~HTML
          <h2>Welcome to Rails SaaS Development</h2>
          <p>Building a Software as a Service (SaaS) application with Ruby on Rails is an excellent choice for modern web development. Rails provides a solid foundation with convention over configuration, making it perfect for rapid development.</p>
          
          <h3>What You'll Learn</h3>
          <ul>
            <li>Setting up a Rails application with modern tools</li>
            <li>Implementing authentication and authorization</li>
            <li>Adding billing with Stripe</li>
            <li>Building a content management system</li>
            <li>Deploying to production</li>
          </ul>
          
          <h3>Prerequisites</h3>
          <p>Before we start, make sure you have:</p>
          <ul>
            <li>Ruby 3.2+ installed</li>
            <li>Rails 8.0+ installed</li>
            <li>PostgreSQL database</li>
            <li>Basic knowledge of web development</li>
          </ul>
          
          <h3>Getting Started</h3>
          <p>Let's begin by creating a new Rails application with our starter template:</p>
          
          <pre><code>rails new myapp --dev -d postgresql -m template.rb</code></pre>
          
          <p>This command creates a new Rails application with all the necessary gems and configurations for SaaS development.</p>
          
          <h3>Next Steps</h3>
          <p>In the next tutorial, we'll explore how to customize the authentication system and add team/workspace functionality.</p>
        HTML,
        category: tutorials_category,
        author: user,
        published: true,
        published_at: 1.week.ago,
        featured: true,
        tags: [rails_tag, tutorial_tag]
      )

      # Create SEO metadata for the post
      post.create_seo_metadata!(
        meta_title: "Getting Started with Rails SaaS Development - Complete Guide",
        meta_description: "Learn how to build a modern SaaS application with Ruby on Rails. Step-by-step tutorial covering authentication, billing, and deployment.",
        meta_keywords: "rails, saas, ruby, tutorial, web development, authentication, billing",
        og_title: "Getting Started with Rails SaaS Development",
        og_description: "Complete guide to building SaaS applications with Ruby on Rails",
        og_type: "article"
      )

      # Create another sample post
      news_category = Category.find_by(name: "News")
      
      Post.create!(
        title: "New Features in Rails 8.0",
        excerpt: "Discover the latest features and improvements in Rails 8.0, including better performance and developer experience.",
        content: <<~HTML
          <h2>Rails 8.0 is Here!</h2>
          <p>The Rails team has released version 8.0 with exciting new features and improvements that make development even more enjoyable.</p>
          
          <h3>Key Features</h3>
          <ul>
            <li>Improved performance across the board</li>
            <li>Better developer experience</li>
            <li>Enhanced security features</li>
            <li>Modern frontend integration</li>
          </ul>
          
          <p>We're excited to integrate these new features into our starter template to provide the best possible foundation for your SaaS applications.</p>
        HTML,
        category: news_category,
        author: user,
        published: true,
        published_at: 2.days.ago,
        tags: [rails_tag]
      )

      puts "Created #{Post.count} blog posts."
    end

    # Create sample pages
    unless Page.exists?
      puts "Creating sample pages..."

      about_page = Page.create!(
        title: "About Us",
        slug: "about",
        content: <<~HTML
          <h1>About Our Company</h1>
          <p>We're passionate about building great software that helps businesses grow and succeed.</p>
          
          <h2>Our Mission</h2>
          <p>To provide the best tools and resources for developers building SaaS applications with Ruby on Rails.</p>
          
          <h2>Our Team</h2>
          <p>Our team consists of experienced developers, designers, and product managers who are committed to creating exceptional software.</p>
          
          <h2>Contact Us</h2>
          <p>Ready to get started? <a href="/contact">Get in touch</a> and let's build something amazing together.</p>
        HTML,
        author: user,
        published: true,
        published_at: 1.month.ago
      )

      about_page.create_seo_metadata!(
        meta_title: "About Us - Rails SaaS Experts",
        meta_description: "Learn about our mission to provide the best tools for Rails SaaS development. Meet our team of experienced developers.",
        meta_keywords: "about, company, rails, saas, team",
        og_title: "About Us - Rails SaaS Experts",
        og_description: "Passionate about building great Rails SaaS applications"
      )

      puts "Created #{Page.count} pages."
    end

    puts "CMS seeds completed successfully!"
  RUBY

  # Update the main seeds file to include CMS seeds
  append_to_file 'db/seeds.rb', <<~'RUBY'

    # Load CMS seeds
    load Rails.root.join('db', 'seeds', 'cms_seeds.rb')
  RUBY

  # Add environment variables to .env.example
  append_to_file '.env.example', <<~'ENV'

    # CMS configuration
    SITEMAP_HOST=http://localhost:3000
  ENV

  # Create view directories
  empty_directory 'app/views/blog'
  empty_directory 'app/views/pages'
  empty_directory 'app/views/sitemaps'
  empty_directory 'app/views/admin/cms'
  empty_directory 'app/views/admin/cms/dashboard'
  empty_directory 'app/views/admin/cms/posts'
  empty_directory 'app/views/admin/cms/pages'
  empty_directory 'app/views/admin/cms/categories'
  empty_directory 'app/views/admin/cms/tags'

  # Copy view templates and other assets
  directory 'views', 'app/views'
  directory 'assets', 'app/assets'

  say_status :synth_cms, "CMS module installed successfully!"
  say_status :synth_cms, "Next steps:"
  say_status :synth_cms, "1. Configure your sitemap host in .env: SITEMAP_HOST=https://yourdomain.com"
  say_status :synth_cms, "2. Run seeds to create sample content: rails db:seed"
  say_status :synth_cms, "3. Access admin interface at /admin/cms"
  say_status :synth_cms, "4. View your blog at /blog"
  say_status :synth_cms, "5. Run tests: bin/rails test test/models/cms/ test/controllers/cms/"
end