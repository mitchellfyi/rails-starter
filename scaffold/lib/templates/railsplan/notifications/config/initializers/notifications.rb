# frozen_string_literal: true

# Configuration for the Notifications module
Rails.application.configure do
  # Notification types and their default settings
  config.notification_types = {
    'invitation_received' => {
      default_channels: [:email, :in_app],
      priority: 'medium',
      auto_dismiss: false
    },
    'invitation_accepted' => {
      default_channels: [:in_app],
      priority: 'low',
      auto_dismiss: true
    },
    'invitation_declined' => {
      default_channels: [:in_app],
      priority: 'low',
      auto_dismiss: true
    },
    'billing_payment_success' => {
      default_channels: [:email, :in_app],
      priority: 'medium',
      auto_dismiss: true
    },
    'billing_payment_failed' => {
      default_channels: [:email, :in_app],
      priority: 'high',
      auto_dismiss: false
    },
    'billing_subscription_cancelled' => {
      default_channels: [:email, :in_app],
      priority: 'high',
      auto_dismiss: false
    },
    'billing_subscription_renewed' => {
      default_channels: [:email, :in_app],
      priority: 'low',
      auto_dismiss: true
    },
    'billing_invoice_generated' => {
      default_channels: [:email],
      priority: 'low',
      auto_dismiss: true
    },
    'job_completed' => {
      default_channels: [:in_app],
      priority: 'low',
      auto_dismiss: true
    },
    'job_failed' => {
      default_channels: [:email, :in_app],
      priority: 'high',
      auto_dismiss: false
    },
    'admin_alert' => {
      default_channels: [:email, :in_app],
      priority: 'high',
      auto_dismiss: false
    },
    'system_maintenance' => {
      default_channels: [:email, :in_app],
      priority: 'high',
      auto_dismiss: false
    },
    'workspace_member_added' => {
      default_channels: [:in_app],
      priority: 'low',
      auto_dismiss: true
    },
    'workspace_member_removed' => {
      default_channels: [:in_app],
      priority: 'low',
      auto_dismiss: true
    }
  }

  # Notification cleanup settings
  config.notification_cleanup = {
    # Clean up notifications older than this many days
    days_to_keep: 30,
    # Run cleanup job this often (cron syntax)
    cleanup_schedule: '0 2 * * *' # Daily at 2 AM
  }

  # Toast notification settings
  config.notification_toasts = {
    # How long toast notifications stay visible (milliseconds)
    auto_dismiss_delay: 5000,
    # Maximum number of toasts to show at once
    max_toasts: 5,
    # Position on screen
    position: 'top-right'
  }

  # Email notification settings
  config.notification_emails = {
    # Default from address for notification emails
    from_address: ENV.fetch('NOTIFICATION_FROM_EMAIL', 'notifications@example.com'),
    # Whether to include unsubscribe links
    include_unsubscribe: true,
    # Rate limiting for email notifications
    rate_limit: {
      max_emails_per_hour: 10,
      max_emails_per_day: 50
    }
  }
end

# Schedule the notification cleanup job if using whenever gem or similar
if defined?(Sidekiq) && Rails.env.production?
  # You can add this to your Sidekiq configuration
  # Sidekiq::Cron::Job.create(
  #   name: 'Notification Cleanup',
  #   cron: Rails.application.config.notification_cleanup[:cleanup_schedule],
  #   class: 'NotificationCleanupJob'
  # )
end