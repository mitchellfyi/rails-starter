# frozen_string_literal: true

# Billing module configuration installer

say_status :billing_config, "Setting up billing configuration"

# Create Stripe configuration
initializer 'stripe.rb', <<~'RUBY'
  # Stripe configuration
  Rails.configuration.stripe = {
    publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
    secret_key: ENV['STRIPE_SECRET_KEY'],
    webhook_endpoint_secret: ENV['STRIPE_WEBHOOK_SECRET']
  }
  
  Stripe.api_key = Rails.configuration.stripe[:secret_key]
  
  # Configure webhook events
  StripeEvent.configure do |events|
    events.subscribe 'customer.subscription.created' do |event|
      SubscriptionEventHandler.handle_subscription_created(event)
    end
    
    events.subscribe 'customer.subscription.updated' do |event|
      SubscriptionEventHandler.handle_subscription_updated(event)
    end
    
    events.subscribe 'customer.subscription.deleted' do |event|
      SubscriptionEventHandler.handle_subscription_cancelled(event)
    end
    
    events.subscribe 'invoice.payment_succeeded' do |event|
      InvoiceEventHandler.handle_payment_succeeded(event)
    end
    
    events.subscribe 'invoice.payment_failed' do |event|
      InvoiceEventHandler.handle_payment_failed(event)
    end
  end
RUBY

# Create Money configuration
initializer 'money.rb', <<~'RUBY'
  # Money configuration for billing
  MoneyRails.configure do |config|
    config.default_currency = :usd
    config.no_cents_if_whole = false
    config.symbol = true
  end
RUBY

# Create billing configuration
initializer 'billing.rb', <<~'RUBY'
  # Billing module configuration
  Rails.application.config.billing = ActiveSupport::OrderedOptions.new
  
  # Default plan configurations
  Rails.application.config.billing.free_trial_days = 14
  Rails.application.config.billing.grace_period_days = 3
  Rails.application.config.billing.dunning_period_days = 10
  
  # Feature limits for different plans
  Rails.application.config.billing.plan_limits = {
    'free' => {
      users: 1,
      projects: 3,
      storage_gb: 1
    },
    'starter' => {
      users: 5,
      projects: 10,
      storage_gb: 10
    },
    'professional' => {
      users: 25,
      projects: 50,
      storage_gb: 100
    },
    'enterprise' => {
      users: -1, # unlimited
      projects: -1,
      storage_gb: 500
    }
  }
RUBY

say_status :billing_config, "Billing configuration created"