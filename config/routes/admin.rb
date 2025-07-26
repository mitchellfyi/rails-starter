# Admin routes for Rails SaaS Starter Template
Rails.application.routes.draw do
  # Admin panel
  namespace :admin do
    root 'dashboard#index'
    
    # Audit logs (main requirement: /admin/audit)
    get 'audit', to: 'audit#index'
    get 'audit/:id', to: 'audit#show', as: :audit_log
    
    # Feature flags with workspace support
    resources :feature_flags do
      member do
        patch :toggle
        patch :toggle_workspace
      end
    end
  end
end