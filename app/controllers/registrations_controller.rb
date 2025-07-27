# frozen_string_literal: true

class RegistrationsController < ApplicationController
  def new
    # Signup page
  end

  def create
    # Handle signup
    redirect_to dashboard_path, notice: 'Account created successfully!'
  end
end