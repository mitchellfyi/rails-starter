# frozen_string_literal: true

require 'test_helper'

class AdminIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = User.create!(
      email: 'admin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: true
    )

    @regular_user = User.create!(
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: false
    )
  end

  test "admin impersonation workflow" do
    skip "Admin impersonation not available in test environment" unless has_admin_routes?
    
    # Login as admin
    login_as(@admin_user)
    
    # Start impersonating regular user
    post admin_impersonate_user_path(@regular_user)
    assert_response :redirect
    
    # Verify impersonation is active
    follow_redirect!
    assert_select '.impersonation-banner', text: /Impersonating/
    
    # Stop impersonation
    delete admin_stop_impersonation_path
    assert_response :redirect
    
    # Verify back to admin
    follow_redirect!
    assert_select '.admin-header'
  end

  test "admin audit log viewing" do
    skip "Admin audit logs not available in test environment" unless has_admin_routes?
    
    login_as(@admin_user)
    
    # Create some activity to audit
    @regular_user.update!(name: 'Updated Name')
    
    # View audit logs
    get admin_audit_logs_path
    assert_response :success
    
    if defined?(AuditLog)
      assert_select 'table' do
        assert_select 'tr', minimum: 1
      end
    end
  end

  test "admin feature flag management" do
    skip "Admin feature flags not available in test environment" unless has_admin_routes?
    
    login_as(@admin_user)
    
    # View feature flags
    get admin_feature_flags_path
    assert_response :success
    
    # Create new feature flag
    if defined?(FeatureFlag)
      post admin_feature_flags_path, params: {
        feature_flag: {
          name: 'test_feature',
          description: 'Test feature flag',
          enabled: true
        }
      }
      assert_response :redirect
      
      # Verify flag was created
      flag = FeatureFlag.find_by(name: 'test_feature')
      assert flag
      assert flag.enabled?
    end
  end

  test "admin user management workflow" do
    skip "Admin user management not available in test environment" unless has_admin_routes?
    
    login_as(@admin_user)
    
    # View users list
    get admin_users_path
    assert_response :success
    assert_select 'table' do
      assert_select 'tr', minimum: 2 # Header + at least one user
    end
    
    # View individual user
    get admin_user_path(@regular_user)
    assert_response :success
    assert_select 'h1', text: /User Details/
    
    # Update user
    patch admin_user_path(@regular_user), params: {
      user: { name: 'Admin Updated Name' }
    }
    assert_response :redirect
    
    @regular_user.reload
    assert_equal 'Admin Updated Name', @regular_user.name
  end

  test "admin dashboard statistics" do
    skip "Admin dashboard not available in test environment" unless has_admin_routes?
    
    login_as(@admin_user)
    get admin_dashboard_path
    assert_response :success
    
    # Check for dashboard metrics
    assert_select '.metric-card', minimum: 1
    assert_select 'h1', text: /Admin Dashboard/
  end

  test "unauthorized admin access prevention" do
    skip "Admin routes not available in test environment" unless has_admin_routes?
    
    # Test unauthenticated access
    get admin_dashboard_path
    assert_response :redirect
    
    # Test regular user access
    login_as(@regular_user)
    get admin_dashboard_path
    assert_response :forbidden
  end

  private

  def has_admin_routes?
    Rails.application.routes.url_helpers.respond_to?(:admin_dashboard_path)
  rescue
    false
  end

  def login_as(user)
    # Mock login for test environment
    # In a real Rails app with Devise, use sign_in user
    session[:user_id] = user.id if defined?(session)
  end
end