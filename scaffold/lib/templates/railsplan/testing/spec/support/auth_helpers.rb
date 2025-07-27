# frozen_string_literal: true

module AuthHelpers
  def sign_in_user(user = nil)
    user ||= create(:user)
    sign_in user
    user
  end

  def create_user_with_workspace(workspace_attributes = {})
    user = create(:user)
    workspace = create(:workspace, workspace_attributes)
    create(:membership, user: user, workspace: workspace, role: 'owner')
    [user, workspace]
  end

  def auth_headers(user)
    token = JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include AuthHelpers
end