# frozen_string_literal: true

# Routes for LLM outputs, feedback system, PromptTemplate management, and AI credentials
# Add these to your application's routes.rb file

Rails.application.routes.draw do
  # AI Provider management (admin only)
  resources :ai_providers
  
  # Workspace-scoped AI credentials
  resources :workspaces, param: :slug do
    resources :ai_credentials do
      member do
        post :test_connection
      end
    end
    
    # Environment credentials management
    resources :environment_credentials, only: [:index] do
      collection do
        get :import_wizard
        post :import
        get :external_secrets
        post :sync_vault
        post :sync_doppler
        post :sync_onepassword
        post :test_all_credentials
      end
    end
  end
  
  # PromptTemplate management routes
  resources :prompt_templates do
    member do
      post :preview
      get :diff
      post :publish
      post :create_version
    end
    resources :prompt_executions, only: [:index, :show, :create, :destroy]
  end

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
      resources :prompt_templates, param: :slug, only: [:index, :show] do
        member do
          post :execute
        end
      end
      
      resources :prompt_executions, only: [:show]
      
      resources :llm_outputs, only: [:index, :show] do
        member do
          post :feedback
          post :re_run
          post :regenerate
        end
      end

      # Endpoint to queue LLM jobs directly
      post 'llm_jobs', to: 'llm_jobs#create'
      
      # Workspace-scoped AI credentials API
      resources :workspaces, param: :slug do
        resources :ai_credentials, only: [:index, :show] do
          member do
            post :test_connection
          end
        end
      end
    end
  end
end