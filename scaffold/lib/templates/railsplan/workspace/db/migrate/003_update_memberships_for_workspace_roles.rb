# frozen_string_literal: true

class UpdateMembershipsForWorkspaceRoles < ActiveRecord::Migration[7.1]
  def up
    # Add workspace_role_id column
    add_reference :memberships, :workspace_role, foreign_key: true
    
    # Create default roles for existing workspaces
    Workspace.find_each do |workspace|
      admin_role = workspace.workspace_roles.create!(
        name: 'admin',
        display_name: 'Administrator',
        description: 'Full access to workspace settings and member management',
        system_role: true,
        priority: 0,
        permissions: {
          'workspace' => ['read', 'update', 'delete'],
          'members' => ['read', 'invite', 'remove', 'manage_roles'],
          'roles' => ['manage'],
          'admin' => ['impersonate']
        }
      )
      
      member_role = workspace.workspace_roles.create!(
        name: 'member',
        display_name: 'Member',
        description: 'Standard member with read access and collaboration features',
        system_role: true,
        priority: 1,
        permissions: {
          'workspace' => ['read'],
          'members' => ['read']
        }
      )
      
      guest_role = workspace.workspace_roles.create!(
        name: 'guest',
        display_name: 'Guest',
        description: 'Limited access for external collaborators',
        system_role: true,
        priority: 2,
        permissions: {
          'workspace' => ['read']
        }
      )
      
      # Update existing memberships
      workspace.memberships.where(role: 'admin').update_all(workspace_role_id: admin_role.id)
      workspace.memberships.where(role: 'member').update_all(workspace_role_id: member_role.id)
      workspace.memberships.where(role: 'guest').update_all(workspace_role_id: guest_role.id)
    end
    
    # Make workspace_role_id required after data migration
    change_column_null :memberships, :workspace_role_id, false
  end
  
  def down
    # Update role column from workspace_role before removing reference
    Membership.joins(:workspace_role).update_all('role = workspace_roles.name')
    
    remove_reference :memberships, :workspace_role, foreign_key: true
  end
end