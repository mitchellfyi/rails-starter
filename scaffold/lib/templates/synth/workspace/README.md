# Workspace Module

Provides comprehensive workspace/team management with slug routing, invitation system, and role-based permissions.

## Features

- **Slug-based routing** for teams/workspaces (`/workspaces/:slug`)
- **Invitation system** to invite users to join workspaces via email
- **Role-based permissions** (admin, member, guest) for access control
- **Integration** with Devise authentication and OmniAuth logins
- **Policy-based authorization** using Pundit

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

## Installation

Run the workspace module installer:

```bash
bin/synth add workspace
rails db:migrate
```

## Configuration

Configure your mailer for invitation emails in `config/environments/*.rb`:

```ruby
config.action_mailer.default_url_options = { host: 'your-domain.com' }
```

## Routes

- `GET /workspaces` - List user's workspaces
- `GET /workspaces/:slug` - Show workspace
- `POST /workspaces` - Create workspace
- `PATCH /workspaces/:slug` - Update workspace
- `DELETE /workspaces/:slug` - Delete workspace
- `GET /workspaces/:slug/memberships` - List workspace members
- `POST /workspaces/:slug/memberships` - Add member
- `PATCH /workspaces/:slug/memberships/:id` - Update membership
- `DELETE /workspaces/:slug/memberships/:id` - Remove member
- `GET /workspaces/:slug/invitations/:id` - Show invitation
- `POST /workspaces/:slug/invitations` - Send invitation
- `PATCH /workspaces/:slug/invitations/:id/accept` - Accept invitation
- `PATCH /workspaces/:slug/invitations/:id/decline` - Decline invitation