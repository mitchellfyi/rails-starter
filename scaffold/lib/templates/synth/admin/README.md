# Admin Module

This module provides a comprehensive admin panel with user management, impersonation, audit logging, and feature flag management.

## Features

- **Admin Dashboard**: Overview statistics and recent activity
- **User Management**: View, edit, and manage user accounts
- **Impersonation**: Safely impersonate users for support purposes
- **Audit Logging**: Track all model changes and user actions
- **Feature Flags**: Toggle features on/off without deployments
- **Authorization**: Pundit-based authorization system

## Installation

```bash
bin/synth add admin
```

This installs:
- Pundit for authorization
- Audited for audit logging
- Flipper for feature flags
- Kaminari for pagination
- Admin controllers and views

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Add admin routes:**
   ```ruby
   namespace :admin do
     root 'dashboard#index'
     resources :users do
       member do
         post :impersonate
         delete :stop_impersonating
       end
     end
     resources :audit_logs, only: [:index, :show]
     resources :feature_flags, only: [:index] do
       member do
         patch :update
       end
     end
   end
   
   # Mount Flipper UI (optional)
   mount Flipper::UI.app(Flipper) => '/admin/flipper'
   ```

3. **Add admin field to User model:**
   ```bash
   rails generate migration AddAdminToUsers admin:boolean
   ```

4. **Include concerns in User model:**
   ```ruby
   class User < ApplicationRecord
     include Impersonatable
     audited except: :password_digest
   end
   ```

## Usage

### Admin Access Control
```ruby
# Make a user an admin
user.update!(admin: true)

# Check admin status
current_user.admin?
```

### User Impersonation
```ruby
# In controller
def impersonate
  impersonate_user(user)
  redirect_to root_path
end

def stop_impersonating
  stop_impersonating_user
  redirect_to admin_users_path
end

# In views
<% if current_user.impersonating? %>
  <div class="impersonation-banner">
    You are impersonating <%= current_user.full_name %>
    <%= link_to "Stop Impersonating", stop_impersonating_path %>
  </div>
<% end %>
```

### Audit Logging
```ruby
# Models are automatically audited
user.update!(name: "New Name")

# View audit trail
user.audits.each do |audit|
  puts "#{audit.action}: #{audit.audited_changes}"
end

# Custom audit comments
user.update!(name: "Admin Update", audit_comment: "Updated by admin")
```

### Feature Flags
```ruby
# Define features
Flipper[:new_dashboard].enable
Flipper[:beta_features].enable_percentage_of_users(25)
Flipper[:admin_panel].enable_group(:admins)

# Check features in code
if Flipper[:new_dashboard].enabled?(current_user)
  render 'new_dashboard'
else
  render 'old_dashboard'
end

# In views
<% if Flipper[:beta_features].enabled?(current_user) %>
  <%= render 'beta_feature' %>
<% end %>
```

### Authorization Policies
```ruby
# Create custom policies
class PostPolicy < ApplicationPolicy
  def index?
    true
  end
  
  def show?
    true
  end
  
  def create?
    user.present?
  end
  
  def update?
    user.admin? || record.author == user
  end
  
  def destroy?
    user.admin? || record.author == user
  end
end

# Use in controllers
def update
  @post = Post.find(params[:id])
  authorize @post
  
  if @post.update(post_params)
    redirect_to @post
  else
    render :edit
  end
end
```

### Dashboard Customization
```ruby
# Add custom stats to dashboard
class Admin::DashboardController < Admin::BaseController
  def index
    @stats = {
      total_users: User.count,
      active_subscriptions: Subscription.active.count,
      revenue_this_month: calculate_monthly_revenue,
      support_tickets: Ticket.open.count
    }
  end
  
  private
  
  def calculate_monthly_revenue
    Invoice.where(created_at: Time.current.beginning_of_month..Time.current)
           .sum(:amount_cents) / 100.0
  end
end
```

## Admin Dashboard Features

### User Management
- View all users with search and pagination
- Edit user profiles and permissions
- View user audit trails
- Impersonate users for support

### Audit Logging
- Track all model changes
- View detailed change history
- Filter by model type and action
- Search audit logs

### Feature Flags
- Toggle features on/off instantly
- Percentage-based rollouts
- Group-based access
- User-specific flags

## Security

- Admin-only access to all admin features
- Impersonation logging and audit trails
- Authorization checks on all actions
- CSRF protection on all forms

## Customization

### Custom Admin Controllers
```ruby
class Admin::PostsController < Admin::BaseController
  def index
    @posts = Post.page(params[:page])
    authorize @posts
  end
  
  def feature
    @post = Post.find(params[:id])
    authorize @post
    
    @post.update!(featured: !@post.featured?)
    redirect_to admin_posts_path
  end
end
```

### Custom Audit Tracking
```ruby
class Post < ApplicationRecord
  audited associated_with: :author
  
  # Custom audit behavior
  def audit_create_comment
    "Post created: #{title}"
  end
end
```

## Testing

```bash
bin/synth test admin
```

## Best Practices

- Always use authorization policies
- Log sensitive administrative actions
- Use feature flags for gradual rollouts
- Monitor admin panel usage
- Regular audit log reviews

## Version

Current version: 1.0.0