# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :email_notifications, inclusion: { in: [true, false] }
  validates :in_app_notifications, inclusion: { in: [true, false] }

  def notification_types
    super || self.class.default_preferences
  end

  def self.default_preferences
    {
      'invitation_received' => { 'email' => true, 'in_app' => true },
      'invitation_accepted' => { 'email' => false, 'in_app' => true },
      'invitation_declined' => { 'email' => false, 'in_app' => true },
      'billing_payment_success' => { 'email' => true, 'in_app' => true },
      'billing_payment_failed' => { 'email' => true, 'in_app' => true },
      'billing_subscription_cancelled' => { 'email' => true, 'in_app' => true },
      'billing_subscription_renewed' => { 'email' => true, 'in_app' => false },
      'billing_invoice_generated' => { 'email' => true, 'in_app' => false },
      'job_completed' => { 'email' => false, 'in_app' => true },
      'job_failed' => { 'email' => true, 'in_app' => true },
      'admin_alert' => { 'email' => true, 'in_app' => true },
      'system_maintenance' => { 'email' => true, 'in_app' => true },
      'workspace_member_added' => { 'email' => false, 'in_app' => true },
      'workspace_member_removed' => { 'email' => false, 'in_app' => true }
    }
  end

  def email_enabled_for?(notification_type)
    return false unless email_notifications?
    
    type_prefs = notification_types[notification_type.to_s]
    return true if type_prefs.nil? # Default to enabled if not configured
    
    type_prefs['email'] == true
  end

  def in_app_enabled_for?(notification_type)
    return false unless in_app_notifications?
    
    type_prefs = notification_types[notification_type.to_s]
    return true if type_prefs.nil? # Default to enabled if not configured
    
    type_prefs['in_app'] == true
  end

  def update_preference_for_type(notification_type, email: nil, in_app: nil)
    current_types = notification_types.dup
    current_types[notification_type.to_s] ||= {}
    
    current_types[notification_type.to_s]['email'] = email unless email.nil?
    current_types[notification_type.to_s]['in_app'] = in_app unless in_app.nil?
    
    update!(notification_types: current_types)
  end

  def channels_for_type(notification_type)
    channels = []
    channels << :email if email_enabled_for?(notification_type)
    channels << :in_app if in_app_enabled_for?(notification_type)
    channels
  end

  # Ensure user has notification preferences
  def self.for_user(user)
    user.notification_preference || user.create_notification_preference!
  end
end