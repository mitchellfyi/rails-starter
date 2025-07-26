# frozen_string_literal: true

class Workspace < ApplicationRecord
  VALID_ROLES = %w[admin member guest].freeze

  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :invitations, dependent: :destroy

  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :description, length: { maximum: 1000 }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  after_create :create_creator_membership

  scope :accessible_by, ->(user) { joins(:memberships).where(memberships: { user: user }) }

  def to_param
    slug
  end

  def admin_members
    members.joins(:memberships).where(memberships: { role: 'admin' })
  end

  def member_role(user)
    memberships.find_by(user: user)&.role
  end

  def has_member?(user)
    memberships.exists?(user: user)
  end

  def admin?(user)
    memberships.exists?(user: user, role: 'admin')
  end

  def member?(user)
    memberships.exists?(user: user, role: 'member')
  end

  def guest?(user)
    memberships.exists?(user: user, role: 'guest')
  end

  private

  def generate_slug
    base_slug = name.parameterize
    counter = 0
    proposed_slug = base_slug

    while Workspace.exists?(slug: proposed_slug)
      counter += 1
      proposed_slug = "#{base_slug}-#{counter}"
    end

    self.slug = proposed_slug
  end

  def create_creator_membership
    memberships.create!(user: created_by, role: 'admin', joined_at: Time.current)
  end
end