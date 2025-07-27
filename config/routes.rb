# frozen_string_literal: true

Rails.application.routes.draw do
  # Home and marketing pages
  root 'home#index'
  get '/docs', to: 'home#docs'
  get '/docs/:doc_path', to: 'home#docs', as: :documentation

  # Load admin routes
  load(Rails.root.join('config/routes/admin.rb'))
  
  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end