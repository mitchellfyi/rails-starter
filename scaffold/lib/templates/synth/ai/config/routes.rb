# frozen_string_literal: true

# Routes for LLM outputs and feedback system
# Add these to your application's routes.rb file

Rails.application.routes.draw do
  resources :llm_outputs, only: [:index, :show] do
    member do
      post :feedback
      post :re_run
      post :regenerate
    end
  end

  # API routes for programmatic access
  namespace :api do
    namespace :v1 do
      resources :llm_outputs, only: [:index, :show] do
        member do
          post :feedback
          post :re_run
          post :regenerate
        end
      end

      # Endpoint to queue LLM jobs directly
      post 'llm_jobs', to: 'llm_jobs#create'
    end
  end
end