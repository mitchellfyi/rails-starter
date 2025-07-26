# frozen_string_literal: true

require 'test_helper'

class BillingModuleTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )

    @plan = Plan.create!(
      name: 'Test Plan',
      stripe_product_id: 'prod_test',
      stripe_price_id: 'price_test',
      amount: 1999,
      interval: 'month',
      trial_period_days: 14,
      features: ['Feature 1', 'Feature 2'],
      metadata: { 'max_users' => 10 },
      feature_limits: { 'api_calls' => 1000 }
    )

    @metered_plan = Plan.create!(
      name: 'Metered Plan',
      stripe_product_id: 'prod_metered',
      stripe_price_id: 'price_metered',
      amount: 999,
      interval: 'month',
      usage_type: 'metered',
      features: ['Metered Feature'],
      feature_limits: { 'api_calls' => 'unlimited' }
    )
  end

  test "plan validation" do
    plan = Plan.new
    assert_not plan.valid?
    assert plan.errors[:name].any?
    assert plan.errors[:stripe_product_id].any?
    assert plan.errors[:stripe_price_id].any?
    assert plan.errors[:amount].any?
    assert plan.errors[:interval].any?
  end

  test "plan price calculation" do
    assert_equal 19.99, @plan.price_in_dollars
    assert @plan.has_trial?
  end

  test "plan feature methods" do
    assert @plan.has_feature?('Feature 1')
    assert_not @plan.has_feature?('Non-existent Feature')
    assert_equal 1000, @plan.feature_limit('api_calls')
    assert_equal 10, @plan.metadata_value('max_users')
  end

  test "plan scopes" do
    inactive_plan = Plan.create!(
      name: 'Inactive Plan',
      stripe_product_id: 'prod_inactive',
      stripe_price_id: 'price_inactive',
      amount: 999,
      interval: 'month',
      active: false
    )

    assert_includes Plan.active, @plan
    assert_not_includes Plan.active, inactive_plan
    assert_includes Plan.visible, @plan
    assert_not_includes Plan.visible, inactive_plan
  end

  test "user billable methods" do
    assert_not @user.subscribed?
    assert_not @user.on_trial?
    assert_equal 0, @user.trial_days_remaining
  end

  test "subscription creation with trial" do
    mock_stripe_customer_and_subscription

    subscription = @user.subscribe_to_plan(@plan)
    
    assert subscription.persisted?
    assert_equal @plan, subscription.plan
    assert_equal 'trialing', subscription.status
    assert subscription.on_trial?
    assert subscription.trial_days_remaining > 0
  end

  test "subscription creation without trial" do
    mock_stripe_customer_and_subscription('active')
    
    no_trial_plan = Plan.create!(
      name: 'No Trial Plan',
      stripe_product_id: 'prod_no_trial',
      stripe_price_id: 'price_no_trial',
      amount: 999,
      interval: 'month',
      trial_period_days: 0
    )

    subscription = @user.subscribe_to_plan(no_trial_plan)
    
    assert subscription.persisted?
    assert_equal 'active', subscription.status
    assert_not subscription.on_trial?
  end

  test "subscription plan change" do
    mock_stripe_customer_and_subscription
    subscription = @user.subscribe_to_plan(@plan)

    # Mock Stripe subscription update
    mock_subscription = mock('subscription')
    mock_subscription.expects(:modify).with(
      items: [{ id: 'item_123', price: @metered_plan.stripe_price_id }]
    )
    Stripe::Subscription.expects(:retrieve).returns(mock_subscription)

    # Mock subscription items
    mock_item = mock('item')
    mock_item.stubs(:id).returns('item_123')
    mock_subscription.stubs(:items).returns(mock('items', data: [mock_item]))

    subscription.change_plan(@metered_plan)
    assert_equal @metered_plan, subscription.plan
  end

  test "subscription cancellation" do
    mock_stripe_customer_and_subscription
    subscription = @user.subscribe_to_plan(@plan)

    # Mock Stripe subscription cancellation
    mock_subscription = mock('subscription')
    mock_subscription.expects(:cancel)
    Stripe::Subscription.expects(:retrieve).returns(mock_subscription)

    subscription.cancel!
    assert_equal 'canceled', subscription.status
    assert subscription.canceled_at.present?
  end

  test "coupon validation" do
    coupon = Coupon.create!(
      code: 'TEST10',
      stripe_coupon_id: 'test10',
      discount_type: 'percentage',
      discount_value: 10,
      valid_until: 1.week.from_now
    )

    assert coupon.valid?
    assert_equal '10% off', coupon.discount_description

    expired_coupon = Coupon.create!(
      code: 'EXPIRED',
      stripe_coupon_id: 'expired',
      discount_type: 'percentage',
      discount_value: 20,
      valid_until: 1.week.ago
    )

    assert_not expired_coupon.valid?
  end

  test "coupon redemption limits" do
    coupon = Coupon.create!(
      code: 'LIMITED',
      stripe_coupon_id: 'limited',
      discount_type: 'fixed',
      discount_value: 500,
      max_redemptions: 1,
      redemptions_count: 1
    )

    assert_not coupon.valid?
  end

  test "invoice pdf generation" do
    invoice = Invoice.create!(
      user: @user,
      stripe_invoice_id: 'in_test123',
      amount_paid: 1999,
      status: 'paid',
      number: 'INV-001'
    )

    pdf_data = invoice.generate_pdf
    assert pdf_data.present?
    assert_equal 'invoice_INV-001.pdf', invoice.download_filename
  end

  test "usage record tracking" do
    mock_stripe_customer_and_subscription
    subscription = @user.subscribe_to_plan(@metered_plan)

    usage_record = UsageRecord.create!(
      user: @user,
      subscription: subscription,
      usage_type: 'api_calls',
      quantity: 100
    )

    assert_equal 100, @user.usage_for_current_period('api_calls')
  end

  test "webhook event processing" do
    event = WebhookEvent.create!(
      stripe_event_id: 'evt_test123',
      event_type: 'invoice.paid'
    )

    assert_not event.processed?
    event.mark_as_processed!
    assert event.processed?
    assert event.successful?
  end

  test "webhook event failure tracking" do
    event = WebhookEvent.new(
      stripe_event_id: 'evt_failed123',
      event_type: 'invoice.payment_failed'
    )

    event.mark_as_failed!('Payment method declined', 'transient')
    
    assert event.failed?
    assert_not event.successful?
    assert_equal 'Payment method declined', event.error_message
    assert_equal 'transient', event.error_type
  end

  test "one time payment creation" do
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)

    # Mock payment intent creation
    mock_payment_intent = mock('payment_intent')
    mock_payment_intent.stubs(:id).returns('pi_test123')
    Stripe::PaymentIntent.expects(:create).with(
      amount: 5000,
      currency: 'usd',
      customer: 'cus_test123',
      description: 'One-time payment for test@example.com'
    ).returns(mock_payment_intent)

    payment_intent = @user.create_one_time_payment(5000)
    assert_equal 'pi_test123', payment_intent.id
  end

  test "billing portal session creation" do
    @user.update!(stripe_customer_id: 'cus_test123')

    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://billing.stripe.com/session')
    Stripe::BillingPortal::Session.expects(:create).with(
      customer: 'cus_test123',
      return_url: 'http://localhost:3000/billing'
    ).returns(mock_session)

    session = @user.create_portal_session('http://localhost:3000/billing')
    assert_equal 'https://billing.stripe.com/session', session.url
  end

  test "subscription status edge cases" do
    mock_stripe_customer_and_subscription('past_due')
    subscription = @user.subscribe_to_plan(@plan)
    subscription.update!(status: 'past_due')

    assert_not subscription.active?
    assert_not subscription.on_trial?

    # Test paused subscription
    subscription.update!(status: 'paused')
    assert_not subscription.active?
  end

  test "trial ending scenarios" do
    mock_stripe_customer_and_subscription('trialing')
    subscription = @user.subscribe_to_plan(@plan)
    
    # Set trial to end tomorrow
    subscription.update!(trial_ends_at: 1.day.from_now)
    assert subscription.on_trial?
    assert_equal 1, subscription.trial_days_remaining

    # Set trial to end in the past
    subscription.update!(trial_ends_at: 1.day.ago)
    assert_not subscription.on_trial?
    assert_equal 0, subscription.trial_days_remaining
  end

  test "webhook retry scenarios" do
    # Test successful webhook processing
    webhook_event = WebhookEvent.create!(
      stripe_event_id: 'evt_success',
      event_type: 'invoice.paid',
      processed_at: Time.current
    )
    assert webhook_event.successful?

    # Test failed webhook with retries
    failed_event = WebhookEvent.create!(
      stripe_event_id: 'evt_failed',
      event_type: 'invoice.payment_failed',
      error_message: 'Temporary network error',
      error_type: 'transient',
      retry_count: 3
    )
    assert failed_event.failed?
    assert_equal 3, failed_event.retry_count
  end

  private

  def mock_stripe_customer_and_subscription(status = 'trialing')
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)

    # Mock Stripe subscription creation
    mock_subscription = mock('subscription')
    mock_subscription.stubs(:id).returns('sub_test123')
    mock_subscription.stubs(:status).returns(status)
    mock_subscription.stubs(:trial_end).returns(status == 'trialing' ? 2.weeks.from_now.to_i : nil)
    mock_subscription.stubs(:current_period_start).returns(Time.current.to_i)
    mock_subscription.stubs(:current_period_end).returns(1.month.from_now.to_i)
    Stripe::Subscription.stubs(:create).returns(mock_subscription)
  end
end