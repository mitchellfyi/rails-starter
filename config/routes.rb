# frozen_string_literal: true

Rails.application.routes.draw do
  # Home and marketing pages
  root 'home#index'
  get '/docs', to: 'home#docs'
  get '/docs/:doc_path', to: 'home#docs', as: :documentation

  # Authentication routes
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  
  get '/signup', to: 'registrations#new'
  post '/signup', to: 'registrations#create'
  
  # Dashboard
  get '/dashboard', to: 'dashboard#index'
  
  # Settings
  get '/settings', to: 'settings#index'
  get '/settings/profile', to: 'settings#profile'
  get '/settings/account', to: 'settings#account'
  get '/settings/notifications', to: 'settings#notifications'

  # Load admin routes
  load(Rails.root.join('config/routes/admin.rb'))
  
  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end