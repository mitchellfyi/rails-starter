# frozen_string_literal: true

# API routes configuration for Rails SaaS Starter Template
# This file should be included in your main application's routes.rb

Rails.application.routes.draw do
  # Mount API documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # JSON:API compliant endpoints
  scope module: :api do
    namespace :api do
      namespace :v1 do
        # LLM and AI endpoints
        resources :llm_jobs, only: [:create]
        resources :llm_outputs, only: [:index, :show] do
          member do
            post :feedback
            post :re_run
            post :regenerate
          end
        end
      end
    end
  end
end