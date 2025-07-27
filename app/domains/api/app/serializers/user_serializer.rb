# frozen_string_literal: true

class UserSerializer < ApplicationSerializer
  attributes :email, :created_at, :updated_at

  # Don't expose sensitive fields by default
  # Add :first_name, :last_name, etc. as needed based on your User model
end