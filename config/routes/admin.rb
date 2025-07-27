# Admin routes for Rails SaaS Starter Template
Rails.application.routes.draw do
  # Admin panel
  namespace :admin do
    root 'dashboard#index'
    
    # Audit logs (main requirement: /admin/audit)
    get 'audit', to: 'audit#index'
    get 'audit/:id', to: 'audit#show', as: :audit_log
    
    # Usage analytics for workspaces
    get 'usage', to: 'usage#index'
    get 'usage/workspace/:workspace_id', to: 'usage#workspace_detail', as: :usage_workspace_detail
    
    # Feature flags with workspace support
    resources :feature_flags do
      member do
        patch :toggle
        patch :toggle_workspace
      end
    end
    
    # MCP fetchers with workspace support
    resources :mcp_fetchers do
      member do
        patch :toggle
        patch :toggle_workspace
      end
    end
  end
end