require 'test_helper'

class OauthAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @identity = identities(:google_identity)
    @identity.update!(user: @user)
    sign_in @user
  end

  test "should disconnect oauth account" do
    assert_difference('Identity.count', -1) do
      delete oauth_account_url(@identity)
    end
    
    assert_redirected_to settings_path
    assert_equal 'Google account disconnected successfully', flash[:notice]
  end

  test "should only allow user to disconnect their own accounts" do
    other_user = users(:two)
    other_identity = identities(:github_identity)
    other_identity.update!(user: other_user)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      delete oauth_account_url(other_identity)
    end
  end

  test "should require authentication" do
    sign_out @user
    
    delete oauth_account_url(@identity)
    assert_redirected_to new_user_session_path
  end
end