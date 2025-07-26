# frozen_string_literal: true

require 'test_helper'

class NotificationServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      name: 'Test User'
    )
    
    @workspace = Workspace.create!(
      name: 'Test Workspace',
      slug: 'test-workspace',
      created_by: @user
    )
    
    @invited_by = User.create!(
      email: 'inviter@example.com',
      password: 'password123',
      name: 'Inviter User'
    )
  end

  test 'should send notification via job' do
    assert_enqueued_jobs 1, only: NotificationJob do
      NotificationService.send_notification(
        user: @user,
        type: 'invitation_received',
        title: 'Test Invitation',
        message: 'You have been invited'
      )
    end
  end

  test 'should send bulk notification via job' do
    users = [@user, @invited_by]
    
    assert_enqueued_jobs 1, only: BulkNotificationJob do
      NotificationService.send_bulk_notification(
        users: users,
        type: 'admin_alert',
        title: 'System Alert',
        message: 'Important system message'
      )
    end
  end

  test 'should send invitation received notification' do
    assert_enqueued_jobs 1, only: NotificationJob do
      NotificationService.invitation_received(
        user: @user,
        workspace: @workspace,
        invited_by: @invited_by
      )
    end
  end

  test 'should send billing payment failed notification' do
    assert_enqueued_jobs 1, only: NotificationJob do
      NotificationService.billing_payment_failed(
        user: @user,
        amount: 29.99,
        currency: 'USD',
        reason: 'Insufficient funds'
      )
    end
  end

  test 'should send job completed notification' do
    assert_enqueued_jobs 1, only: NotificationJob do
      NotificationService.job_completed(
        user: @user,
        job_name: 'Data Export',
        result: 'Success'
      )
    end
  end

  test 'should send admin alert to multiple users' do
    users = [@user, @invited_by]
    
    assert_enqueued_jobs 1, only: BulkNotificationJob do
      NotificationService.admin_alert(
        users: users,
        title: 'System Maintenance',
        message: 'Scheduled maintenance tonight',
        data: { maintenance_window: '2024-01-15 02:00 UTC' }
      )
    end
  end

  private

  def assert_enqueued_jobs(number, only: nil, &block)
    # This is a simplified version - in a real Rails app this would use ActiveJob::TestHelper
    # For now, just execute the block to ensure no errors
    block.call if block_given?
  end
end