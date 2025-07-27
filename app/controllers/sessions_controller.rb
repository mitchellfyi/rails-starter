# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    # Login page
  end

  def create
    # Handle login
    redirect_to dashboard_path, notice: 'Logged in successfully!'
  end

  def destroy
    # Handle logout
    redirect_to root_path, notice: 'Logged out successfully!'
  end
end