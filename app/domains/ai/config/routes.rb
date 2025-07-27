# frozen_string_literal: true

# Routes for LLM outputs, feedback system, and PromptTemplate management
# Add these to your application's routes.rb file

Rails.application.routes.draw do
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

  # Workspace-scoped AI resources
  resources :workspaces, param: :slug do
    # AI Datasets management
    resources :ai_datasets do
      member do
        post :process
        get 'download/:file_id', to: 'ai_datasets#download', as: 'download_file'
      end
    end
    
    # Workspace Embedding Sources management
    resources :workspace_embedding_sources do
      member do
        post :test
        post :refresh
      end
    end
    
    # Workspace AI Configuration
    resource :workspace_ai_config, path: 'ai_config', only: [:show, :edit, :update] do
      member do
        post :test_rag
        post :reset_to_defaults
      end
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
      
      # Workspace-scoped API endpoints
      resources :workspaces, param: :slug do
        resources :ai_datasets, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :process
          end
        end
        
        resources :workspace_embedding_sources, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :test
            post :refresh
          end
        end
        
        resource :workspace_ai_config, path: 'ai_config', only: [:show, :update] do
          member do
            post :test_rag
          end
        end
      end
    end
  end
end