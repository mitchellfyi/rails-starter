# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user

  validates :notification_type, presence: true
  validates :title, presence: true
  validates :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :active, -> { where(dismissed_at: nil) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Notification types
  TYPES = %w[
    invitation_received
    invitation_accepted
    invitation_declined
    billing_payment_success
    billing_payment_failed
    billing_subscription_cancelled
    billing_subscription_renewed
    billing_invoice_generated
    job_completed
    job_failed
    admin_alert
    system_maintenance
    workspace_member_added
    workspace_member_removed
  ].freeze

  validates :notification_type, inclusion: { in: TYPES }

  def read?
    read_at.present?
  end

  def unread?
    read_at.nil?
  end

  def dismissed?
    dismissed_at.present?
  end

  def active?
    dismissed_at.nil?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def mark_as_unread!
    update!(read_at: nil) if read?
  end

  def dismiss!
    update!(dismissed_at: Time.current) unless dismissed?
  end

  def data
    super || {}
  end

  def icon
    case notification_type
    when 'invitation_received', 'invitation_accepted', 'invitation_declined'
      'users'
    when /^billing_/
      'credit-card'
    when /^job_/
      'clock'
    when 'admin_alert'
      'exclamation-triangle'
    when 'system_maintenance'
      'cog'
    when /^workspace_/
      'building'
    else
      'bell'
    end
  end

  def priority
    case notification_type
    when 'admin_alert', 'system_maintenance'
      'high'
    when /^billing_payment_failed/, /^job_failed/
      'high'
    when /^billing_/, 'invitation_received'
      'medium'
    else
      'low'
    end
  end

  def css_classes
    classes = ['notification-item']
    classes << 'unread' if unread?
    classes << "priority-#{priority}"
    classes << "type-#{notification_type.dasherize}"
    classes.join(' ')
  end

  # Class methods for bulk operations
  def self.mark_all_read_for_user(user)
    user.notifications.unread.update_all(read_at: Time.current)
  end

  def self.dismiss_all_for_user(user)
    user.notifications.active.update_all(dismissed_at: Time.current)
  end

  def self.cleanup_old_notifications(days = 30)
    where('created_at < ?', days.days.ago).destroy_all
  end
end