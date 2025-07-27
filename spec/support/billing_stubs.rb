# frozen_string_literal: true

require_relative '../../lib/api_client_factory'

# spec/support/billing_stubs.rb

module BillingStubs
  def stub_stripe_customer_create
    # Use the factory to get the appropriate client
    if ApiClientFactory.stub_mode?
      # In test mode, the factory will return stub client automatically
      client = ApiClientFactory.stripe_client
      allow(Stripe::Customer).to receive(:create) do |params|
        client.customer.create(params)
      end
    else
      # Fallback to original stubbing for non-test environments
      allow(Stripe::Customer).to receive(:create).and_return(OpenStruct.new(id: 'cus_mock'))
    end
  end

  def stub_stripe_subscription_create
    if ApiClientFactory.stub_mode?
      client = ApiClientFactory.stripe_client
      allow(Stripe::Subscription).to receive(:create) do |params|
        client.subscription.create(params)
      end
    else
      # Fallback to original stubbing
      allow(Stripe::Subscription).to receive(:create).and_return(
        OpenStruct.new(
          id: 'sub_mock', 
          status: 'active', 
          trial_end: nil, 
          current_period_start: Time.current.to_i, 
          current_period_end: 1.month.from_now.to_i
        )
      )
    end
  end

  def stub_stripe_payment_method_create
    if ApiClientFactory.stub_mode?
      client = ApiClientFactory.stripe_client
      allow(Stripe::PaymentMethod).to receive(:create) do |params|
        client.payment_method.create(params)
      end
    else
      allow(Stripe::PaymentMethod).to receive(:create).and_return(
        OpenStruct.new(id: 'pm_mock', type: 'card')
      )
    end
  end

  def stub_stripe_invoice_create
    if ApiClientFactory.stub_mode?
      client = ApiClientFactory.stripe_client
      allow(Stripe::Invoice).to receive(:create) do |params|
        client.invoice.create(params)
      end
    else
      allow(Stripe::Invoice).to receive(:create).and_return(
        OpenStruct.new(id: 'in_mock', status: 'draft')
      )
    end
  end

  def stub_stripe_webhook_event(event_type, data = {})
    # Enhanced webhook stubbing with deterministic data
    if ApiClientFactory.stub_mode?
      event_id = "evt_#{Digest::MD5.hexdigest("#{event_type}-#{data}")[0..14]}"
      
      {
        'id' => event_id,
        'object' => 'event',
        'type' => event_type,
        'data' => {
          'object' => data.merge('id' => data[:id] || "obj_#{Random.hex(8)}")
        },
        'created' => Time.current.to_i,
        'livemode' => false,
        'api_version' => '2020-08-27'
      }
    else
      # Fallback to original StripeMock
      StripeMock.mock_webhook_event(event_type, data)
    end
  end

  # Additional helper methods for comprehensive billing testing
  def create_test_customer(email: 'test@example.com', name: 'Test Customer')
    if ApiClientFactory.stub_mode?
      client = ApiClientFactory.stripe_client
      client.customer.create(email: email, name: name)
    else
      OpenStruct.new(id: 'cus_test', email: email, name: name)
    end
  end

  def create_test_subscription(customer_id: 'cus_test', price_id: 'price_test')
    if ApiClientFactory.stub_mode?
      client = ApiClientFactory.stripe_client
      client.subscription.create(
        customer: customer_id,
        items: [{ price: price_id }]
      )
    else
      OpenStruct.new(id: 'sub_test', customer: customer_id, status: 'active')
    end
  end
end

RSpec.configure do |config|
  config.include BillingStubs
end
