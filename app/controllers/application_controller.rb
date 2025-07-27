# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true

  # Include common helpers
  include HomeHelper
  
  private

  def current_user
    # Placeholder for authentication
    nil
  end

  def user_signed_in?
    current_user.present?
  end
end