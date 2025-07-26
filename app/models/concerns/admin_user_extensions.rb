# frozen_string_literal: true

# User model extensions for admin functionality
module AdminUserExtensions
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, dependent: :destroy
  end

  def admin?
    admin == true
  end

  def can_admin?
    admin?
  end
end

# Add to User model when it exists
if defined?(User)
  User.include AdminUserExtensions
end