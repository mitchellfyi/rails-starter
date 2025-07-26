# frozen_string_literal: true

class NotificationService
  class << self
    # Send a notification to a single user
    def send_notification(user:, type:, title:, message:, data: {}, channels: [:email, :in_app])
      NotificationJob.perform_later(
        user.id,
        type.to_s,
        title,
        message,
        data,
        channels
      )
    end

    # Send notifications to multiple users
    def send_bulk_notification(users:, type:, title:, message:, data: {}, channels: [:email, :in_app])
      user_ids = users.respond_to?(:pluck) ? users.pluck(:id) : Array(users).map(&:id)
      
      BulkNotificationJob.perform_later(
        user_ids,
        type.to_s,
        title,
        message,
        data,
        channels
      )
    end

    # Convenience methods for common notification types
    
    def invitation_received(user:, workspace:, invited_by:)
      send_notification(
        user: user,
        type: 'invitation_received',
        title: 'New workspace invitation',
        message: "You've been invited to join #{workspace.name}",
        data: {
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          invited_by_name: invited_by.name,
          invited_by_id: invited_by.id
        }
      )
    end

    def invitation_accepted(user:, workspace:, accepter:)
      send_notification(
        user: user,
        type: 'invitation_accepted',
        title: 'Invitation accepted',
        message: "#{accepter.name} has joined #{workspace.name}",
        data: {
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          accepter_name: accepter.name,
          accepter_id: accepter.id
        },
        channels: [:in_app] # Usually only in-app for this type
      )
    end

    def billing_payment_failed(user:, amount:, currency: 'USD', reason: nil)
      send_notification(
        user: user,
        type: 'billing_payment_failed',
        title: 'Payment failed',
        message: "Your payment of #{amount} #{currency} has failed. Please update your payment method.",
        data: {
          amount: amount,
          currency: currency,
          reason: reason
        }
      )
    end

    def billing_payment_success(user:, amount:, currency: 'USD')
      send_notification(
        user: user,
        type: 'billing_payment_success',
        title: 'Payment successful',
        message: "Your payment of #{amount} #{currency} has been processed successfully.",
        data: {
          amount: amount,
          currency: currency
        }
      )
    end

    def job_completed(user:, job_name:, result: nil)
      send_notification(
        user: user,
        type: 'job_completed',
        title: 'Job completed',
        message: "Your #{job_name} job has completed successfully.",
        data: {
          job_name: job_name,
          result: result
        },
        channels: [:in_app] # Usually only in-app for job completions
      )
    end

    def job_failed(user:, job_name:, error: nil)
      send_notification(
        user: user,
        type: 'job_failed',
        title: 'Job failed',
        message: "Your #{job_name} job has failed. Please try again or contact support.",
        data: {
          job_name: job_name,
          error: error
        }
      )
    end

    def admin_alert(users:, title:, message:, data: {})
      send_bulk_notification(
        users: users,
        type: 'admin_alert',
        title: title,
        message: message,
        data: data
      )
    end

    def system_maintenance(users:, start_time:, end_time:, description: nil)
      send_bulk_notification(
        users: users,
        type: 'system_maintenance',
        title: 'Scheduled maintenance',
        message: "System maintenance is scheduled from #{start_time.strftime('%B %d at %I:%M %p')} to #{end_time.strftime('%I:%M %p')}.",
        data: {
          start_time: start_time.iso8601,
          end_time: end_time.iso8601,
          description: description
        }
      )
    end

    def workspace_member_added(user:, workspace:, new_member:, added_by:)
      send_notification(
        user: user,
        type: 'workspace_member_added',
        title: 'New team member',
        message: "#{new_member.name} has been added to #{workspace.name}",
        data: {
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          new_member_name: new_member.name,
          new_member_id: new_member.id,
          added_by_name: added_by.name,
          added_by_id: added_by.id
        },
        channels: [:in_app] # Usually only in-app
      )
    end

    def workspace_member_removed(user:, workspace:, removed_member:, removed_by:)
      send_notification(
        user: user,
        type: 'workspace_member_removed',
        title: 'Team member removed',
        message: "#{removed_member.name} has been removed from #{workspace.name}",
        data: {
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          removed_member_name: removed_member.name,
          removed_member_id: removed_member.id,
          removed_by_name: removed_by.name,
          removed_by_id: removed_by.id
        },
        channels: [:in_app] # Usually only in-app
      )
    end
  end
end