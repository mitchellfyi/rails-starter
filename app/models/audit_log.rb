# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_action, ->(action) { where(action: action) }
  scope :for_resource_type, ->(type) { where(resource_type: type) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  
  validates :action, presence: true
  validates :description, presence: true
  
  def self.create_log(user:, action:, resource_type: nil, resource_id: nil, description:, metadata: {}, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      description: description,
      metadata: metadata,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_impersonation(admin_user, target_user, action, ip_address: nil, user_agent: nil)
    create_log(
      user: admin_user,
      action: "impersonation_#{action}",
      resource_type: 'User',
      resource_id: target_user.id,
      description: "#{action.humanize} impersonating user: #{target_user.email}",
      metadata: {
        target_user_id: target_user.id,
        target_user_email: target_user.email
      },
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_login(user, ip_address: nil, user_agent: nil)
    create_log(
      user: user,
      action: 'login',
      resource_type: 'User',
      resource_id: user.id,
      description: "User logged in: #{user.email}",
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def self.log_ai_review(user, ai_output, rating, ip_address: nil, user_agent: nil)
    create_log(
      user: user,
      action: 'ai_output_review',
      resource_type: 'AIOutput',
      description: "Reviewed AI output with rating: #{rating}",
      metadata: {
        ai_output_id: ai_output&.id,
        rating: rating,
        output_preview: ai_output&.content&.truncate(100)
      },
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
  
  def formatted_metadata
    return 'None' if metadata.blank?
    metadata.map { |k, v| "#{k.humanize}: #{v}" }.join(', ')
  end
  
  def time_ago
    ActionController::Base.helpers.time_ago_in_words(created_at)
  end
end