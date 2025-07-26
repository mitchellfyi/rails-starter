# frozen_string_literal: true

# Configure routes with API namespace
say "🛣️  Setting up routes..."

route <<~RUBY
  # API routes
  namespace :api do
    namespace :v1 do
      resources :workspaces, only: [:index, :show, :create, :update, :destroy] do
        resources :memberships, only: [:index, :show, :create, :update, :destroy]
      end
      resources :users, only: [:index, :show, :update]
    end
  end

  # Web routes
  resources :workspaces do
    resources :memberships, except: [:new, :edit]
    resources :invitations, only: [:show, :create, :update]
  end
  
  # Auth domain routes
  scope module: :auth do
    devise_for :users, controllers: {
      sessions: 'sessions',
      omniauth_callbacks: 'sessions'
    }
    resource :two_factor, only: [:show, :enable, :disable]
  end
RUBY

# Mount Sidekiq web UI behind authentication
route "require 'sidekiq/web'\nauthenticate :user, lambda { |u| u.respond_to?(:admin?) && u.admin? } do\n  mount Sidekiq::Web => '/admin/sidekiq'\nend"