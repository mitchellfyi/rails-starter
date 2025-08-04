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

  # RailsPlan Chat Interface
  get '/railsplan/chat', to: 'railsplan_chat#index'
  post '/railsplan/chat', to: 'railsplan_chat#create'
  get '/railsplan/chat/preview', to: 'railsplan_chat#preview_query'
  post '/railsplan/chat/explain', to: 'railsplan_chat#explain_query'
  get '/railsplan/schema', to: 'railsplan_chat#schema_summary'

  # Load admin routes
  load(Rails.root.join('config/routes/admin.rb'))
  
  # Mount RailsPlan Web Engine for AI Dashboard
  mount Railsplan::Web::Engine, at: "/railsplan" if defined?(Railsplan::Web::Engine)
  
  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end