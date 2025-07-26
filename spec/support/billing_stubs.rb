# frozen_string_literal: true

# spec/support/billing_stubs.rb

module BillingStubs
  def stub_stripe_customer_create
    allow(Stripe::Customer).to receive(:create).and_return(OpenStruct.new(id: 'cus_mock'))
  end

  def stub_stripe_subscription_create
    allow(Stripe::Subscription).to receive(:create).and_return(OpenStruct.new(id: 'sub_mock', status: 'active', trial_end: nil, current_period_start: Time.current.to_i, current_period_end: 1.month.from_now.to_i))
  end

  def stub_stripe_webhook_event(event_type, data = {})
    StripeMock.mock_webhook_event(event_type, data)
  end
end

RSpec.configure do |config|
  config.include BillingStubs
end
