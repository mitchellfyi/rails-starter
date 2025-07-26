# frozen_string_literal: true

# CMS module installer
say 'Installing CMS module...'

# Add ActionText if not already installed
rails_command 'action_text:install' unless File.exist?('app/models/action_text')

# Create CMS models
generate :model, 'Post', 'title:string', 'slug:string', 'excerpt:text', 'published_at:datetime', 'user:references'
generate :model, 'Page', 'title:string', 'slug:string', 'published_at:datetime'
generate :model, 'Category', 'name:string', 'slug:string'
generate :model, 'PostCategory', 'post:references', 'category:references'

# Create CMS controllers
generate :controller, 'Posts', 'index', 'show'
generate :controller, 'Pages', 'show'
generate :controller, 'Admin::Posts', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'
generate :controller, 'Admin::Pages', 'index', 'show', 'new', 'create', 'edit', 'update', 'destroy'

# Add CMS routes
route "resources :posts, only: [:index, :show]\nresources :pages, only: [:show], param: :slug"
route "namespace :admin do\n  resources :posts\n  resources :pages\nend"

say 'CMS module installed! Visit /admin/posts to manage content'