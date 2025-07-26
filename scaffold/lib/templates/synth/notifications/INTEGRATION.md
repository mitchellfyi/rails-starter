# Notifications Module Integration Guide

This guide shows how to integrate the notifications module with other modules in the Rails SaaS Starter Template.

## Integration with Workspace Module

### Sending Invitation Notifications

In your `InvitationsController` (workspace module), add notification sending:

```ruby
# app/domains/workspaces/app/controllers/invitations_controller.rb
class InvitationsController < ApplicationController
  def create
    @invitation = @workspace.invitations.build(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      # Send invitation email (existing)
      InvitationMailer.invite_user(@invitation).deliver_later
      
      # Send notification (new)
      if User.exists?(email: @invitation.email)
        user = User.find_by(email: @invitation.email)
        NotificationService.invitation_received(
          user: user,
          workspace: @workspace,
          invited_by: current_user
        )
      end
      
      redirect_to workspace_path(@workspace), notice: 'Invitation sent!'
    else
      render :new
    end
  end

  def accept
    if @invitation.accept!(current_user)
      # Notify workspace members about new member
      @workspace.users.where.not(id: current_user.id).find_each do |member|
        NotificationService.workspace_member_added(
          user: member,
          workspace: @workspace,
          new_member: current_user,
          added_by: @invitation.invited_by
        )
      end
      
      redirect_to workspace_path(@workspace), notice: 'Welcome to the workspace!'
    else
      redirect_to invitation_path(@invitation), alert: 'Could not accept invitation.'
    end
  end
end
```

### Membership Changes

In your `MembershipsController`:

```ruby
# app/domains/workspaces/app/controllers/memberships_controller.rb
class MembershipsController < ApplicationController
  def destroy
    @membership = @workspace.memberships.find(params[:id])
    removed_user = @membership.user
    
    if @membership.destroy
      # Notify remaining members
      @workspace.users.where.not(id: [current_user.id, removed_user.id]).find_each do |member|
        NotificationService.workspace_member_removed(
          user: member,
          workspace: @workspace,
          removed_member: removed_user,
          removed_by: current_user
        )
      end
      
      redirect_to workspace_memberships_path(@workspace), notice: 'Member removed.'
    else
      redirect_to workspace_memberships_path(@workspace), alert: 'Could not remove member.'
    end
  end
end
```

## Integration with Billing Module

### Payment Notifications

In your billing webhooks or payment processing:

```ruby
# app/domains/billing/app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  def stripe
    case event.type
    when 'payment_intent.succeeded'
      payment_intent = event.data.object
      user = User.find_by(stripe_customer_id: payment_intent.customer)
      
      if user
        NotificationService.billing_payment_success(
          user: user,
          amount: payment_intent.amount / 100.0, # Convert from cents
          currency: payment_intent.currency.upcase
        )
      end
      
    when 'payment_intent.payment_failed'
      payment_intent = event.data.object
      user = User.find_by(stripe_customer_id: payment_intent.customer)
      
      if user
        NotificationService.billing_payment_failed(
          user: user,
          amount: payment_intent.amount / 100.0,
          currency: payment_intent.currency.upcase,
          reason: payment_intent.last_payment_error&.message
        )
      end
      
    when 'customer.subscription.deleted'
      subscription = event.data.object
      user = User.find_by(stripe_customer_id: subscription.customer)
      
      if user
        NotificationService.send_notification(
          user: user,
          type: 'billing_subscription_cancelled',
          title: 'Subscription cancelled',
          message: 'Your subscription has been cancelled. You can reactivate it anytime.',
          data: { 
            subscription_id: subscription.id,
            cancelled_at: Time.at(subscription.canceled_at).iso8601
          }
        )
      end
    end
  end
end
```

### Subscription Management

In your subscription controller:

```ruby
# app/domains/billing/app/controllers/subscriptions_controller.rb
class SubscriptionsController < ApplicationController
  def create
    # ... subscription creation logic ...
    
    if @subscription.save
      NotificationService.send_notification(
        user: current_user,
        type: 'billing_subscription_created',
        title: 'Subscription activated',
        message: "Your #{@subscription.plan_name} subscription is now active!",
        data: { 
          plan: @subscription.plan_name,
          amount: @subscription.amount,
          currency: @subscription.currency
        }
      )
    end
  end
end
```

## Integration with AI Module

### Job Completion Notifications

In your AI job classes:

```ruby
# app/domains/ai/app/jobs/llm_processing_job.rb
class LlmProcessingJob < ApplicationJob
  def perform(user_id, prompt, options = {})
    user = User.find(user_id)
    
    begin
      # Process LLM request
      result = LlmService.process(prompt, options)
      
      # Save result
      llm_output = user.llm_outputs.create!(
        prompt: prompt,
        response: result.response,
        model: result.model,
        tokens_used: result.tokens
      )
      
      # Notify user of completion
      NotificationService.job_completed(
        user: user,
        job_name: 'LLM Processing',
        result: {
          output_id: llm_output.id,
          tokens_used: result.tokens,
          model: result.model
        }
      )
      
    rescue => error
      # Notify user of failure
      NotificationService.job_failed(
        user: user,
        job_name: 'LLM Processing',
        error: error.message
      )
      
      raise error
    end
  end
end
```

## Integration with Admin Module

### Admin Alerts

In your admin controllers:

```ruby
# app/domains/admin/app/controllers/announcements_controller.rb
class AnnouncementsController < ApplicationController
  def create
    @announcement = Announcement.new(announcement_params)
    
    if @announcement.save
      # Send to all users or specific groups
      users = case @announcement.target_audience
               when 'all_users'
                 User.all
               when 'premium_users'
                 User.joins(:subscription).where(subscriptions: { status: 'active' })
               else
                 User.none
               end
      
      NotificationService.admin_alert(
        users: users,
        title: @announcement.title,
        message: @announcement.message,
        data: {
          announcement_id: @announcement.id,
          priority: @announcement.priority,
          expires_at: @announcement.expires_at&.iso8601
        }
      )
      
      redirect_to admin_announcements_path, notice: 'Announcement sent!'
    else
      render :new
    end
  end
end
```

### System Maintenance Notifications

```ruby
# app/domains/admin/app/controllers/maintenance_controller.rb
class MaintenanceController < ApplicationController
  def create
    maintenance = MaintenanceWindow.new(maintenance_params)
    
    if maintenance.save
      # Notify all users about upcoming maintenance
      NotificationService.system_maintenance(
        users: User.all,
        start_time: maintenance.start_time,
        end_time: maintenance.end_time,
        description: maintenance.description
      )
      
      redirect_to admin_maintenance_path, notice: 'Maintenance scheduled and users notified!'
    else
      render :new
    end
  end
end
```

## Adding Notification Bell to Layout

Add the notification bell to your application layout:

```erb
<!-- app/views/layouts/application.html.erb -->
<nav class="navbar">
  <div class="nav-items">
    <!-- Other navigation items -->
    
    <!-- Notification bell -->
    <%= render 'shared/notification_bell' %>
    
    <!-- User menu -->
    <%= render 'shared/user_menu' %>
  </div>
</nav>

<!-- Notification toast container (should be outside main content) -->
<%= render 'shared/notification_toasts' if user_signed_in? %>
```

## Custom Notification Types

You can extend the notification system with custom types:

```ruby
# In an initializer or module
Rails.application.config.after_initialize do
  # Add custom notification types
  custom_types = %w[
    document_shared
    comment_received
    mention_received
    backup_completed
    security_alert
  ]
  
  Notification::TYPES.concat(custom_types)
  
  # Add custom default preferences
  custom_preferences = {
    'document_shared' => { 'email' => false, 'in_app' => true },
    'comment_received' => { 'email' => true, 'in_app' => true },
    'mention_received' => { 'email' => true, 'in_app' => true },
    'backup_completed' => { 'email' => false, 'in_app' => true },
    'security_alert' => { 'email' => true, 'in_app' => true }
  }
  
  NotificationPreference.class_eval do
    define_method :default_preferences do
      super().merge(custom_preferences)
    end
  end
end
```

Then use them in your application:

```ruby
NotificationService.send_notification(
  user: @user,
  type: 'document_shared',
  title: 'Document shared with you',
  message: "#{current_user.name} shared '#{@document.title}' with you",
  data: {
    document_id: @document.id,
    shared_by: current_user.id,
    shared_at: Time.current.iso8601
  }
)
```

## Real-time Updates with Turbo Streams

To enable real-time notifications, ensure your layout includes:

```erb
<!-- app/views/layouts/application.html.erb -->
<%= turbo_stream_from "notifications_#{current_user.id}" if user_signed_in? %>
<%= turbo_stream_from "notification_toasts_#{current_user.id}" if user_signed_in? %>
```

## Performance Considerations

1. **Rate Limiting**: The notification system includes rate limiting configuration for emails
2. **Background Processing**: All notifications are processed asynchronously via jobs
3. **Cleanup**: Old notifications are automatically cleaned up based on configuration
4. **Indexing**: Consider adding database indexes for frequently queried notification attributes

## Testing Integration

When testing controllers that send notifications, mock the service:

```ruby
# In your controller tests
test "should send notification on invitation create" do
  NotificationService.expects(:invitation_received).once
  
  post workspace_invitations_path(@workspace), params: {
    invitation: { email: 'test@example.com', role: 'member' }
  }
  
  assert_redirected_to workspace_path(@workspace)
end
```