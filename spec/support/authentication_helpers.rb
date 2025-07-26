# frozen_string_literal: true

# spec/support/authentication_helpers.rb

module AuthenticationHelpers
  def sign_in_as(user)
    # Implement your sign-in logic here, e.g., using Devise Test Helpers
    # For request specs:
    # sign_in user
    # For system specs:
    # visit new_user_session_path
    # fill_in 'Email', with: user.email
    # fill_in 'Password', with: user.password
    # click_button 'Log in'
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end