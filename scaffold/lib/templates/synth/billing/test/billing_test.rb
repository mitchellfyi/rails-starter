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
      trial_period_days: 14
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

  test "user billable methods" do
    assert_not @user.subscribed?
    assert_not @user.on_trial?
    assert_equal 0, @user.trial_days_remaining
  end

  test "subscription creation" do
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)

    # Mock Stripe subscription creation
    mock_subscription = mock('subscription')
    mock_subscription.stubs(:id).returns('sub_test123')
    mock_subscription.stubs(:status).returns('trialing')
    mock_subscription.stubs(:trial_end).returns(2.weeks.from_now.to_i)
    mock_subscription.stubs(:current_period_start).returns(Time.current.to_i)
    mock_subscription.stubs(:current_period_end).returns(1.month.from_now.to_i)
    Stripe::Subscription.stubs(:create).returns(mock_subscription)

    subscription = @user.subscribe_to_plan(@plan)
    
    assert subscription.persisted?
    assert_equal @plan, subscription.plan
    assert_equal 'trialing', subscription.status
    assert subscription.on_trial?
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
end