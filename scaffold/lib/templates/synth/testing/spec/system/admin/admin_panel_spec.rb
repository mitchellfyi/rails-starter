# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Panel', type: :system do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
    sign_in admin_user
    driven_by(:rack_test)
  end

  describe 'admin dashboard' do
    scenario 'admin can access dashboard' do
      visit admin_root_path
      
      expect(page).to have_content('Admin Dashboard')
      expect(page).to have_content('Users')
      expect(page).to have_content('Workspaces')
      expect(page).to have_content('System Stats')
    end

    scenario 'regular user cannot access admin dashboard' do
      sign_out admin_user
      sign_in regular_user
      
      visit admin_root_path
      
      expect(page).to have_content('Access denied')
        .or(have_content('Not authorized'))
        .or(have_current_path(root_path))
    end
  end

  describe 'user management' do
    let!(:users) { create_list(:user, 3) }

    scenario 'admin views user list' do
      visit admin_users_path
      
      expect(page).to have_content('Users')
      users.each do |user|
        expect(page).to have_content(user.email)
      end
    end

    scenario 'admin searches users' do
      target_user = create(:user, email: 'findme@example.com')
      
      visit admin_users_path
      fill_in 'Search', with: 'findme'
      click_button 'Search'
      
      expect(page).to have_content('findme@example.com')
      expect(page).not_to have_content(users.first.email)
    end

    scenario 'admin views user details' do
      user = users.first
      workspace = create(:workspace)
      create(:membership, user: user, workspace: workspace)
      
      visit admin_user_path(user)
      
      expect(page).to have_content(user.email)
      expect(page).to have_content('Workspaces')
      expect(page).to have_content(workspace.name)
    end

    scenario 'admin impersonates user' do
      user = users.first
      
      visit admin_user_path(user)
      click_button 'Impersonate'
      
      expect(page).to have_content("Impersonating #{user.email}")
      expect(page).to have_link('Stop Impersonating')
    end

    scenario 'admin stops impersonating user' do
      user = users.first
      
      visit admin_user_path(user)
      click_button 'Impersonate'
      click_link 'Stop Impersonating'
      
      expect(page).not_to have_content("Impersonating")
      expect(page).to have_content('Admin Dashboard')
    end
  end

  describe 'workspace management' do
    let!(:workspaces) { create_list(:workspace, 3, :with_owner) }

    scenario 'admin views workspace list' do
      visit admin_workspaces_path
      
      expect(page).to have_content('Workspaces')
      workspaces.each do |workspace|
        expect(page).to have_content(workspace.name)
      end
    end

    scenario 'admin views workspace details' do
      workspace = workspaces.first
      
      visit admin_workspace_path(workspace)
      
      expect(page).to have_content(workspace.name)
      expect(page).to have_content('Members')
      expect(page).to have_content('Subscription')
    end

    scenario 'admin suspends workspace' do
      workspace = workspaces.first
      
      visit admin_workspace_path(workspace)
      click_button 'Suspend Workspace'
      
      fill_in 'Reason', with: 'Terms of service violation'
      click_button 'Confirm Suspension'
      
      expect(page).to have_content('Workspace suspended')
      expect(page).to have_content('Suspended')
    end
  end

  describe 'audit logs' do
    let!(:audit_logs) { create_list(:audit_log, 5) }

    scenario 'admin views audit log' do
      visit admin_audit_logs_path
      
      expect(page).to have_content('Audit Log')
      audit_logs.each do |log|
        expect(page).to have_content(log.action)
        expect(page).to have_content(log.resource_type)
      end
    end

    scenario 'admin filters audit logs by action' do
      create_audit_log = create(:audit_log, action: 'create')
      update_audit_log = create(:audit_log, :update_action)
      
      visit admin_audit_logs_path
      select 'create', from: 'Action'
      click_button 'Filter'
      
      expect(page).to have_content(create_audit_log.resource_type)
      expect(page).not_to have_content(update_audit_log.action)
    end

    scenario 'admin views audit log details' do
      log = audit_logs.first
      
      visit admin_audit_log_path(log)
      
      expect(page).to have_content(log.action)
      expect(page).to have_content(log.resource_type)
      expect(page).to have_content(log.ip_address)
      expect(page).to have_content('Changes')
    end
  end

  describe 'feature flags' do
    let!(:feature_flags) { create_list(:feature_flag, 3) }

    scenario 'admin views feature flags' do
      visit admin_feature_flags_path
      
      expect(page).to have_content('Feature Flags')
      feature_flags.each do |flag|
        expect(page).to have_content(flag.name)
        expect(page).to have_content(flag.description)
      end
    end

    scenario 'admin toggles feature flag' do
      flag = create(:feature_flag, enabled: true)
      
      visit admin_feature_flags_path
      
      within("[data-flag-id='#{flag.id}']") do
        click_button 'Disable'
      end
      
      expect(page).to have_content('Feature flag updated')
      flag.reload
      expect(flag.enabled).to be false
    end

    scenario 'admin creates new feature flag' do
      visit admin_feature_flags_path
      click_link 'New Feature Flag'
      
      fill_in 'Name', with: 'beta_feature'
      fill_in 'Description', with: 'New beta feature for testing'
      fill_in 'Rollout percentage', with: '50'
      check 'Enabled'
      
      click_button 'Create Feature Flag'
      
      expect(page).to have_content('Feature flag created')
      expect(page).to have_content('beta_feature')
    end

    scenario 'admin updates feature flag rollout' do
      flag = create(:feature_flag, rollout_percentage: 25)
      
      visit edit_admin_feature_flag_path(flag)
      
      fill_in 'Rollout percentage', with: '75'
      click_button 'Update Feature Flag'
      
      expect(page).to have_content('Feature flag updated')
      flag.reload
      expect(flag.rollout_percentage).to eq(75)
    end
  end

  describe 'system monitoring' do
    scenario 'admin views system stats' do
      visit admin_root_path
      
      expect(page).to have_content('Total Users')
      expect(page).to have_content('Active Workspaces')
      expect(page).to have_content('Revenue')
      expect(page).to have_content('System Health')
    end

    scenario 'admin views Sidekiq dashboard' do
      visit admin_sidekiq_path
      
      expect(page).to have_content('Sidekiq')
      expect(page).to have_content('Jobs')
      expect(page).to have_content('Queues')
    end

    scenario 'admin performs database maintenance' do
      visit admin_system_path
      
      click_button 'Run Database Cleanup'
      
      expect(page).to have_content('Database cleanup completed')
        .or(have_content('Maintenance task started'))
    end
  end

  describe 'bulk operations' do
    let!(:users) { create_list(:user, 5) }

    scenario 'admin performs bulk user export' do
      visit admin_users_path
      
      check 'Select all'
      click_button 'Export Selected'
      
      expect(page.response_headers['Content-Type']).to include('text/csv')
    end

    scenario 'admin sends bulk notifications' do
      visit admin_users_path
      
      users.first(3).each do |user|
        check "user_#{user.id}"
      end
      
      click_button 'Send Notification'
      
      fill_in 'Subject', with: 'Important Update'
      fill_in 'Message', with: 'Please update your profile'
      click_button 'Send'
      
      expect(page).to have_content('Notifications sent to 3 users')
    end
  end

  describe 'security features' do
    scenario 'admin actions are logged' do
      user = create(:user)
      
      visit admin_user_path(user)
      click_button 'Impersonate'
      
      visit admin_audit_logs_path
      
      expect(page).to have_content('admin_impersonation')
      expect(page).to have_content(user.email)
    end

    scenario 'admin session timeout' do
      # Simulate session timeout
      page.driver.browser.clear_cookies
      
      visit admin_users_path
      
      expect(page).to have_content('Please sign in')
        .or(have_current_path(new_user_session_path))
    end
  end
end