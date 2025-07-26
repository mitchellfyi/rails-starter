# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Workspace Management', type: :system do
  let(:user) { create(:user) }

  before do
    sign_in user
    driven_by(:rack_test)
  end

  describe 'workspace creation' do
    scenario 'user creates a new workspace' do
      visit new_workspace_path
      
      fill_in 'Name', with: 'My New Workspace'
      click_button 'Create Workspace'
      
      expect(page).to have_content('My New Workspace')
        .or(have_content('Workspace was successfully created'))
    end

    scenario 'user cannot create workspace without name' do
      visit new_workspace_path
      
      fill_in 'Name', with: ''
      click_button 'Create Workspace'
      
      expect(page).to have_content("Name can't be blank")
        .or(have_content('Please review the problems'))
    end
  end

  describe 'workspace navigation' do
    let!(:workspace) { create(:workspace, name: 'Test Workspace') }
    let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

    scenario 'user can view their workspace' do
      visit workspace_path(workspace)
      
      expect(page).to have_content('Test Workspace')
    end

    scenario 'user can navigate to workspace via slug' do
      visit "/#{workspace.slug}"
      
      expect(page).to have_content('Test Workspace')
    end
  end

  describe 'workspace settings' do
    let!(:workspace) { create(:workspace, name: 'Test Workspace') }
    let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

    scenario 'owner can edit workspace settings' do
      visit edit_workspace_path(workspace)
      
      fill_in 'Name', with: 'Updated Workspace Name'
      click_button 'Update Workspace'
      
      expect(page).to have_content('Updated Workspace Name')
        .or(have_content('Workspace was successfully updated'))
    end

    scenario 'owner can invite members' do
      visit workspace_path(workspace)
      
      click_link 'Invite Members'
      
      fill_in 'Email', with: 'newmember@example.com'
      select 'Member', from: 'Role'
      click_button 'Send Invitation'
      
      expect(page).to have_content('Invitation sent')
        .or(have_content('newmember@example.com'))
    end
  end

  describe 'workspace members' do
    let!(:workspace) { create(:workspace, name: 'Test Workspace') }
    let!(:owner_membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }
    let!(:member_user) { create(:user, email: 'member@example.com') }
    let!(:member_membership) { create(:membership, user: member_user, workspace: workspace, role: 'member') }

    scenario 'owner can view workspace members' do
      visit workspace_path(workspace)
      click_link 'Members'
      
      expect(page).to have_content(user.email)
      expect(page).to have_content('member@example.com')
    end

    scenario 'owner can change member roles' do
      visit workspace_members_path(workspace)
      
      within("[data-member-id='#{member_membership.id}']") do
        select 'Admin', from: 'Role'
        click_button 'Update Role'
      end
      
      expect(page).to have_content('Role updated')
        .or(have_content('Admin'))
    end

    scenario 'owner can remove members' do
      visit workspace_members_path(workspace)
      
      within("[data-member-id='#{member_membership.id}']") do
        click_button 'Remove'
      end
      
      expect(page).not_to have_content('member@example.com')
    end
  end

  describe 'workspace permissions' do
    let!(:workspace) { create(:workspace, name: 'Test Workspace') }
    let!(:other_user) { create(:user) }

    scenario 'non-member cannot access workspace' do
      sign_out user
      sign_in other_user
      
      visit workspace_path(workspace)
      
      expect(page).to have_content('Access denied')
        .or(have_content('Not found'))
        .or(have_current_path(root_path))
    end

    scenario 'member cannot access admin settings' do
      create(:membership, user: user, workspace: workspace, role: 'member')
      
      visit edit_workspace_path(workspace)
      
      expect(page).to have_content('Access denied')
        .or(have_content('Not authorized'))
        .or(have_current_path(workspace_path(workspace)))
    end
  end
end