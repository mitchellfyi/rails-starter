# Workspace Module

Provides comprehensive workspace/team management with slug routing, invitation system, and role-based permissions.

## Features

- **Slug-based routing** for teams/workspaces (`/workspaces/:slug`)
- **Invitation system** to invite users to join workspaces via email
- **Role-based permissions** (admin, member, guest) for access control
- **Integration** with Devise authentication and OmniAuth logins
- **Policy-based authorization** using Pundit

## Installation

1. Install the workspace module:
   ```bash
   bin/railsplan add workspace
   ```

2. Run the migrations:
   ```bash
   rails db:migrate
   ```

3. Configure email delivery in your environment files:
   ```ruby
   # config/environments/development.rb
   config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
   
   # config/environments/production.rb  
   config.action_mailer.default_url_options = { host: 'your-domain.com' }
   ```

4. Add workspace navigation to your layout (optional):
   ```erb
   <!-- app/views/layouts/application.html.erb -->
   <% if user_signed_in? && current_user.workspaces.any? %>
     <nav class="workspace-nav">
       <%= link_to "Workspaces", workspaces_path %>
     </nav>
   <% end %>
   ```

## Models

### Workspace
- `name`: The display name of the workspace
- `slug`: URL-friendly identifier (auto-generated from name)  
- `description`: Optional description of the workspace
- `created_by`: Reference to the user who created the workspace

### Membership
- `workspace`: Reference to the workspace
- `user`: Reference to the user
- `role`: User role in the workspace (admin, member, guest)
- `invited_by`: Reference to the user who invited this member
- `joined_at`: Timestamp when the user joined

### Invitation
- `workspace`: Reference to the workspace
- `email`: Email address of the invited user
- `role`: Intended role for the invited user
- `token`: Unique token for the invitation link
- `invited_by`: Reference to the user who sent the invitation
- `accepted_at`: Timestamp when invitation was accepted
- `expires_at`: Timestamp when invitation expires

## Roles & Permissions

### Admin
- Full workspace management (create, update, delete)
- Manage members (invite, remove, change roles)
- View all workspace content

### Member
- View workspace content
- Manage own membership (leave workspace)
- Limited workspace actions based on specific permissions

### Guest
- Limited read-only access to specific workspace content
- Cannot manage members or workspace settings

## Usage

### Creating a Workspace
```ruby
workspace = current_user.created_workspaces.create!(
  name: "My Team",
  description: "Our awesome team workspace"
)
```

### Inviting Users
```ruby
invitation = workspace.invitations.create!(
  email: "user@example.com",
  role: "member",
  invited_by: current_user
)
InvitationMailer.invite_user(invitation).deliver_later
```

### Authorization
```ruby
# In controllers
authorize @workspace
authorize @membership

# In views
<% if policy(@workspace).update? %>
  <%= link_to "Edit", edit_workspace_path(@workspace) %>
<% end %>
```

## User Model Integration

The workspace module automatically extends your User model with workspace-related associations and methods:

```ruby
# Available methods on User instances
user.workspaces              # All workspaces user belongs to
user.admin_workspaces        # Workspaces where user is admin
user.member_workspaces       # Workspaces where user is member  
user.guest_workspaces        # Workspaces where user is guest
user.created_workspaces      # Workspaces created by user
user.pending_invitations     # Valid pending invitations for user

user.admin_of?(workspace)    # Check if user is admin of workspace
user.member_of?(workspace)   # Check if user is member of workspace
user.workspace_role(workspace) # Get user's role in workspace
```

## Routes

The module provides these routes:

- `GET /workspaces` - List user's workspaces
- `GET /workspaces/:slug` - Show workspace
- `POST /workspaces` - Create workspace
- `PATCH /workspaces/:slug` - Update workspace
- `DELETE /workspaces/:slug` - Delete workspace
- `GET /workspaces/:slug/memberships` - List workspace members
- `POST /workspaces/:slug/memberships` - Add member
- `PATCH /workspaces/:slug/memberships/:id` - Update membership
- `DELETE /workspaces/:slug/memberships/:id` - Remove member
- `GET /invitations/:token` - Show invitation (public)
- `POST /workspaces/:slug/invitations` - Send invitation
- `PATCH /invitations/:token/accept` - Accept invitation (public)
- `PATCH /invitations/:token/decline` - Decline invitation (public)

## Testing

The module includes comprehensive tests:

- **Model tests**: Workspace, Membership, Invitation models
- **Controller tests**: All CRUD operations and authorization
- **Integration tests**: Complete invitation flow
- **Fixtures**: Test data for workspaces, memberships, invitations

Run tests:
```bash
rails test test/models/workspace_test.rb
rails test test/controllers/workspaces_controller_test.rb
rails test test/integration/workspace_invitation_flow_test.rb
```

## Customization

### Views
All views use Tailwind CSS classes and can be customized by editing files in `app/views/`:
- `workspaces/` - Workspace CRUD views
- `memberships/` - Member management views  
- `invitations/` - Invitation acceptance views
- `invitation_mailer/` - Email templates

### Policies
Authorization policies can be customized in `app/policies/`:
- `workspace_policy.rb` - Workspace access control
- `membership_policy.rb` - Membership management control

### Models
Extend the models with additional functionality by reopening classes or using concerns.

## Security Considerations

- All workspace actions require proper authorization via Pundit policies
- Invitation tokens are cryptographically secure and expire after 7 days
- Email validation prevents invitation spam
- Unique constraints prevent duplicate memberships
- Admin permissions required for workspace management

## Multi-tenancy Ready

This workspace module provides the foundation for multi-tenant SaaS applications:

- Slug-based routing for clean URLs
- Role-based access control
- Secure invitation system
- Scalable team management
- Integration with existing authentication

Perfect for building team-based applications, project management tools, or any SaaS that needs workspace organization.