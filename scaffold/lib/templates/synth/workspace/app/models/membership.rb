# frozen_string_literal: true

class Membership < ApplicationRecord
  VALID_ROLES = %w[admin member guest].freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :invited_by, class_name: 'User', foreign_key: 'invited_by_id', optional: true

  validates :role, presence: true, inclusion: { in: VALID_ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }

  before_validation :set_joined_at, if: -> { joined_at.blank? && user.present? }

  scope :admins, -> { where(role: 'admin') }
  scope :members, -> { where(role: 'member') }
  scope :guests, -> { where(role: 'guest') }
  scope :recent, -> { order(joined_at: :desc) }

  def admin?
    role == 'admin'
  end

  def member?
    role == 'member'
  end

  def guest?
    role == 'guest'
  end

  def can_manage_workspace?
    admin?
  end

  def can_invite_members?
    admin?
  end

  def can_remove_members?
    admin?
  end

  private

  def set_joined_at
    self.joined_at = Time.current
  end
end