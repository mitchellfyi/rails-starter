# frozen_string_literal: true

# Billing module gem dependencies installer

say_status :billing_gems, "Installing billing module gems"

# Stripe and billing related gems (check if not already present)
unless File.read('Gemfile').include?('stripe')
  gem 'stripe', '~> 15.3'  # Use consistent version with main template
end

gem 'stripe_event', '~> 2.7'
gem 'money-rails', '~> 1.15'

say_status :billing_gems, "Billing module gems added to Gemfile"