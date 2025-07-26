# frozen_string_literal: true

require 'test_helper'

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in @user
  end

  test 'should get index' do
    get workspaces_url
    assert_response :success
    assert_select 'h1', 'My Workspaces'
  end

  test 'should show workspace' do
    get workspace_url(@workspace)
    assert_response :success
    assert_select 'h1', @workspace.name
  end

  test 'should get new' do
    get new_workspace_url
    assert_response :success
    assert_select 'h1', 'Create New Workspace'
  end

  test 'should create workspace' do
    assert_difference('Workspace.count') do
      post workspaces_url, params: { workspace: { name: 'New Workspace', description: 'Test description' } }
    end

    workspace = Workspace.last
    assert_redirected_to workspace_url(workspace)
    assert_equal @user, workspace.created_by
    assert workspace.admin?(@user)
  end

  test 'should not create workspace with invalid params' do
    assert_no_difference('Workspace.count') do
      post workspaces_url, params: { workspace: { name: '' } }
    end

    assert_response :unprocessable_entity
  end

  test 'should get edit for admin' do
    get edit_workspace_url(@workspace)
    assert_response :success
  end

  test 'should update workspace as admin' do
    patch workspace_url(@workspace), params: { workspace: { name: 'Updated Name' } }
    assert_redirected_to workspace_url(@workspace)
    
    @workspace.reload
    assert_equal 'Updated Name', @workspace.name
  end

  test 'should destroy workspace as admin' do
    assert_difference('Workspace.count', -1) do
      delete workspace_url(@workspace)
    end

    assert_redirected_to workspaces_url
  end
end