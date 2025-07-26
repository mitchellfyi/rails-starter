# frozen_string_literal: true

# Synth Billing module installer for the Rails SaaS starter template.

say_status :synth_billing, "Installing Billing module"

# Add billing specific gems to the application's Gemfile
add_gem 'stripe'

# Run bundle install and set up billing configuration after gems are installed
after_bundle do
  # Create an initializer for Stripe configuration
  initializer 'stripe.rb', <<~'RUBY'
    # Stripe configuration
    Rails.configuration.stripe = {
      publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
      secret_key: ENV['STRIPE_SECRET_KEY'],
      webhook_secret: ENV['STRIPE_WEBHOOK_SECRET']
    }
    
    Stripe.api_key = Rails.configuration.stripe[:secret_key]
  RUBY

  # Generate models for billing
  say_status :synth_billing, "Generating billing models and migrations"
  
  # Plan model for subscription plans
  generate :model, 'Plan',
    'name:string',
    'description:text',
    'amount_cents:integer',
    'currency:string',
    'interval:string', # month, year
    'interval_count:integer',
    'trial_period_days:integer',
    'active:boolean',
    'stripe_id:string:index',
    'features:text' # JSON array
    
  # Product model for one-time purchases and metered billing
  generate :model, 'Product',
    'name:string',
    'description:text',
    'amount_cents:integer',
    'currency:string',
    'product_type:string', # one_time, metered
    'billing_scheme:string', # per_unit, tiered
    'stripe_id:string:index',
    'metadata:text' # JSON
    
  # Subscription model
  generate :model, 'Subscription',
    'user:references',
    'plan:references',
    'stripe_id:string:index',
    'status:string:index',
    'current_period_start:datetime',
    'current_period_end:datetime',
    'trial_start:datetime',
    'trial_end:datetime',
    'cancel_at_period_end:boolean',
    'canceled_at:datetime'
    
  # Coupon model
  generate :model, 'Coupon',
    'name:string',
    'description:text',
    'stripe_id:string:index',
    'percent_off:integer',
    'amount_off_cents:integer',
    'currency:string',
    'duration:string', # once, repeating, forever
    'duration_in_months:integer',
    'max_redemptions:integer',
    'times_redeemed:integer',
    'redeem_by:datetime',
    'active:boolean',
    'metadata:text' # JSON
    
  # Usage Record model for metered billing
  generate :model, 'UsageRecord',
    'subscription:references',
    'product:references',
    'quantity:integer',
    'timestamp:datetime',
    'recorded_at:datetime'
    
  # Invoice model (optional)
  generate :model, 'Invoice',
    'user:references',
    'subscription:references',
    'stripe_id:string:index',
    'amount_due_cents:integer',
    'amount_paid_cents:integer',
    'currency:string',
    'status:string:index',
    'invoice_date:datetime'

  # Add indexes and constraints
  create_file 'db/migrate/add_billing_indexes.rb', <<~RUBY
    class AddBillingIndexes < ActiveRecord::Migration[7.1]
      def change
        add_index :plans, :active
        add_index :subscriptions, [:user_id, :status]
        add_index :usage_records, [:subscription_id, :timestamp]
        add_index :coupons, :active
        add_index :coupons, :redeem_by
      end
    end
  RUBY

  say_status :synth_billing, "Billing module installed. Please run migrations and configure your Stripe keys."
  say_status :synth_billing, "Add your Stripe keys to .env: STRIPE_PUBLISHABLE_KEY, STRIPE_SECRET_KEY"
  say_status :synth_billing, "Run 'rails db:seed' to create example plans, products, and coupons."
end