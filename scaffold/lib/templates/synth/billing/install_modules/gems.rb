# frozen_string_literal: true

# Billing module gem dependencies installer

say_status :billing_gems, "Installing billing module gems"

# Stripe and billing related gems
gem 'stripe', '~> 10.0'
gem 'stripe_event', '~> 2.7'
gem 'money-rails', '~> 1.15'

say_status :billing_gems, "Billing module gems added to Gemfile"