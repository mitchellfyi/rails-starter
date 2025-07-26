# Notifications Module

The Notifications module provides a comprehensive notification system for Rails SaaS applications, supporting both in-app and email notifications for important events.

## Features

- **Real-time in-app notifications** with toast messages and notification feed
- **Email notifications** via ActionMailer and background jobs
- **User preferences** to control which notifications they receive via which channels
- **Event-driven notifications** for invitations, billing updates, failed payments, job completions, and admin alerts
- **Turbo/Stimulus integration** for real-time UI updates
- **Notification management** with read/unread status and dismissal

## Models

- **Notification**: Stores individual notifications with type, message, and metadata
- **NotificationPreference**: User preferences for notification channels and types

## Installation

Add the notifications module to your Rails application:

```bash
bin/synth add notifications
```

This will:
- Create notification and notification preference models
- Set up controllers for managing notifications
- Install notification mailer for email delivery
- Add background jobs for async notification processing
- Create views for notification management
- Add Stimulus controllers for real-time updates

## Usage

### Sending Notifications

```ruby
# Send a notification to a user
NotificationService.send_notification(
  user: user,
  type: 'invitation_received',
  title: 'New invitation',
  message: "You've been invited to join #{workspace.name}",
  data: { workspace_id: workspace.id }
)

# Send with specific channels
NotificationService.send_notification(
  user: user,
  type: 'billing_payment_failed',
  title: 'Payment failed',
  message: 'Your subscription payment has failed',
  channels: [:email, :in_app]
)
```

### Notification Types

The module supports the following notification types:
- `invitation_received` - Team/workspace invitations
- `billing_payment_success` - Successful payments
- `billing_payment_failed` - Failed payments
- `billing_subscription_cancelled` - Subscription cancellations
- `job_completed` - Background job completions
- `admin_alert` - Administrative alerts
- `system_maintenance` - System maintenance notices

### User Preferences

Users can control their notification preferences:

```ruby
# Get user's preferences
preferences = user.notification_preferences

# Update preferences
user.notification_preferences.update(
  email_notifications: true,
  in_app_notifications: true,
  notification_types: {
    'invitation_received' => { email: true, in_app: true },
    'billing_payment_failed' => { email: true, in_app: false }
  }
)
```

### In-App Notifications

The module provides Stimulus controllers for real-time notification updates:

```erb
<!-- Notification feed -->
<div data-controller="notifications" data-notifications-user-id-value="<%= current_user.id %>">
  <div id="notification-feed">
    <%= render 'notifications/feed', notifications: current_user.notifications.unread %>
  </div>
</div>

<!-- Toast notifications -->
<div id="notification-toasts" data-controller="notification-toasts">
  <!-- Toast messages will appear here -->
</div>
```

## Configuration

### Email Templates

Customize email templates in `app/views/notification_mailer/`:
- `notification_email.html.erb` - HTML email template
- `notification_email.text.erb` - Text email template

### Notification Types

Configure notification types in `config/initializers/notifications.rb`:

```ruby
Rails.application.config.notification_types = {
  'invitation_received' => {
    default_channels: [:email, :in_app],
    email_template: 'invitation_received'
  },
  'billing_payment_failed' => {
    default_channels: [:email, :in_app],
    email_template: 'billing_payment_failed'
  }
  # ... more types
}
```

## Integration with Other Modules

The notifications module integrates seamlessly with other modules:

### Workspace Module
- Invitation notifications when users are invited to workspaces
- Member addition/removal notifications

### Billing Module  
- Payment success/failure notifications
- Subscription change notifications
- Invoice notifications

### AI Module
- Job completion notifications for LLM processing
- Error notifications for failed AI operations

### Admin Module
- Administrative alerts and announcements
- System maintenance notifications

## API Endpoints

The module provides RESTful API endpoints:

- `GET /notifications` - List user notifications
- `PATCH /notifications/:id/read` - Mark notification as read
- `DELETE /notifications/:id` - Dismiss notification
- `GET /notification_preferences` - Get user preferences  
- `PATCH /notification_preferences` - Update user preferences

## Background Jobs

Notifications are processed asynchronously using background jobs:

- `NotificationJob` - Sends individual notifications
- `BulkNotificationJob` - Sends notifications to multiple users
- `NotificationCleanupJob` - Cleans up old notifications

## Testing

Run notification tests:

```bash
bin/synth test notifications
```

This runs the complete test suite including:
- Model tests for notifications and preferences
- Controller tests for API endpoints
- Integration tests for notification flow
- Job tests for background processing
- Mailer tests for email delivery