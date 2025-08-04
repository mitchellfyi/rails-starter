# frozen_string_literal: true

Railsplan::Web::Engine.routes.draw do
  root 'dashboard#index'
  
  # Dashboard Overview
  get 'dashboard', to: 'dashboard#index'
  
  # Schema Browser
  get 'schema', to: 'schema#index'
  get 'schema/:model', to: 'schema#show', as: :schema_model
  post 'schema/search', to: 'schema#search'
  
  # AI Code Generator
  get 'generate', to: 'generator#index'
  post 'generate', to: 'generator#create'
  post 'generate/preview', to: 'generator#preview'
  post 'generate/apply', to: 'generator#apply'
  
  # Prompt History & Replay
  get 'prompts', to: 'prompts#index'
  get 'prompts/:id', to: 'prompts#show', as: :prompt
  post 'prompts/:id/replay', to: 'prompts#replay', as: :replay_prompt
  
  # Upgrade Tool
  get 'upgrade', to: 'upgrade#index'
  post 'upgrade', to: 'upgrade#create'
  post 'upgrade/preview', to: 'upgrade#preview'
  post 'upgrade/apply', to: 'upgrade#apply'
  
  # Doctor Tool
  get 'doctor', to: 'doctor#index'
  post 'doctor/run', to: 'doctor#run'
  post 'doctor/fix', to: 'doctor#fix'
  
  # AI Agent Console
  get 'chat', to: 'chat#index'
  post 'chat', to: 'chat#create'
  get 'chat/context', to: 'chat#context'
end