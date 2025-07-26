# frozen_string_literal: true

class Invitation < ApplicationRecord
  VALID_ROLES = %w[admin member guest].freeze

  belongs_to :workspace
  belongs_to :invited_by, class_name: 'User', foreign_key: 'invited_by_id'
  belongs_to :workspace_role

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: VALID_ROLES }
  validates :token, presence: true, uniqueness: true
  validates :email, uniqueness: { scope: :workspace_id, conditions: -> { where(accepted_at: nil) } }
  validate :workspace_role_belongs_to_workspace

  before_validation :generate_token, if: -> { token.blank? }
  before_validation :set_expiration, if: -> { expires_at.blank? }
  before_validation :sync_role_from_workspace_role, if: :workspace_role_changed?

  scope :pending, -> { where(accepted_at: nil) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { pending.where('expires_at > ?', Time.current) }

  def pending?
    accepted_at.nil?
  end

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def valid?
    pending? && !expired?
  end

  def accept!(user = nil)
    return false if accepted? || expired?

    # Find or create user if not provided
    user ||= User.find_by(email: email)
    return false unless user

    # Check if user is already a member
    return false if workspace.has_member?(user)

    transaction do
      # Create membership
      workspace.memberships.create!(
        user: user,
        workspace_role: workspace_role,
        role: workspace_role.name,
        invited_by: invited_by,
        joined_at: Time.current
      )

      # Mark invitation as accepted
      update!(accepted_at: Time.current)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def decline!
    return false if accepted?
    destroy
  end

  def to_param
    token
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at = 7.days.from_now
  end

  def workspace_role_belongs_to_workspace
    return unless workspace_role && workspace
    
    unless workspace_role.workspace_id == workspace.id
      errors.add(:workspace_role, 'must belong to the same workspace')
    end
  end

  def sync_role_from_workspace_role
    self.role = workspace_role&.name if workspace_role
  end
end