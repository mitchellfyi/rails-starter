# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Authentication', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'user registration' do
    scenario 'user signs up successfully' do
      visit new_user_registration_path
      
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      
      click_button 'Sign up'
      
      expect(page).to have_content('Welcome! You have signed up successfully')
        .or(have_content('confirmation link'))
        .or(have_content('signed up'))
    end

    scenario 'user cannot sign up with invalid email' do
      visit new_user_registration_path
      
      fill_in 'Email', with: 'invalid-email'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      
      click_button 'Sign up'
      
      expect(page).to have_content('Email is invalid')
        .or(have_content('Please review the problems'))
    end

    scenario 'user cannot sign up with mismatched passwords' do
      visit new_user_registration_path
      
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'different'
      
      click_button 'Sign up'
      
      expect(page).to have_content("Password confirmation doesn't match")
        .or(have_content('Please review the problems'))
    end
  end

  describe 'user login' do
    let!(:user) { create(:user, email: 'user@example.com', password: 'password123') }

    scenario 'user signs in successfully' do
      visit new_user_session_path
      
      fill_in 'Email', with: 'user@example.com'
      fill_in 'Password', with: 'password123'
      
      click_button 'Log in'
      
      expect(page).to have_content('Signed in successfully')
        .or(have_content('Welcome'))
        .or(have_content('Dashboard'))
    end

    scenario 'user cannot sign in with wrong password' do
      visit new_user_session_path
      
      fill_in 'Email', with: 'user@example.com'
      fill_in 'Password', with: 'wrongpassword'
      
      click_button 'Log in'
      
      expect(page).to have_content('Invalid Email or password')
        .or(have_content('Invalid login'))
    end

    scenario 'user can sign out' do
      sign_in user
      visit root_path
      
      click_link 'Sign out', match: :first
      
      expect(page).to have_content('Signed out successfully')
        .or(have_content('Sign in'))
    end
  end

  describe 'password reset' do
    let!(:user) { create(:user, email: 'user@example.com') }

    scenario 'user requests password reset' do
      visit new_user_password_path
      
      fill_in 'Email', with: 'user@example.com'
      click_button 'Send me reset password instructions'
      
      expect(page).to have_content('You will receive an email')
        .or(have_content('reset password instructions'))
    end
  end
end