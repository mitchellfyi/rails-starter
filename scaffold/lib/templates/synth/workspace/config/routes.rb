# Workspace module routes
# Add these routes to your config/routes.rb file

# Workspace routes with slug-based routing
resources :workspaces, param: :slug do
  # Nested membership management
  resources :memberships, except: [:show, :new, :edit] do
    member do
      patch :update_role
    end
  end
  
  # Nested invitation management
  resources :invitations, only: [:show, :create] do
    member do
      patch :accept
      patch :decline
    end
  end
  
  # Nested workspace role management
  resources :workspace_roles, except: [:show] do
    member do
      patch :update_permissions
    end
  end
  
  # Nested impersonation management
  resources :impersonations, only: [:index, :show, :new, :create, :destroy]
end

# Public invitation routes (no authentication required for viewing)
get '/invitations/:id', to: 'invitations#show', as: 'invitation'
patch '/invitations/:id/accept', to: 'invitations#accept', as: 'accept_invitation'
patch '/invitations/:id/decline', to: 'invitations#decline', as: 'decline_invitation'

# Root route can be set to workspaces index for workspace-centric apps
# root 'workspaces#index'