# frozen_string_literal: true

# Billing Module Factories  
# Factories for plans, products, subscriptions, and coupons

FactoryBot.define do
  # Plan factory for subscription plans
  factory :plan do
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.sentence }
    amount_cents { rand(1000..10000) }
    currency { 'usd' }
    interval { 'month' }
    interval_count { 1 }
    trial_period_days { 14 }
    active { true }
    stripe_id { "plan_#{SecureRandom.hex(8)}" }
    features { [Faker::Lorem.sentence, Faker::Lorem.sentence] }

    trait :free do
      name { 'Free Plan' }
      amount_cents { 0 }
      trial_period_days { 0 }
      features { ['Basic features', 'Email support'] }
    end

    trait :starter do
      name { 'Starter' }
      amount_cents { 2900 } # $29
      features { ['Up to 1,000 requests', 'Email support', '3 workspaces'] }
    end

    trait :professional do
      name { 'Professional' }
      amount_cents { 9900 } # $99
      features { ['Up to 10,000 requests', 'Priority support', 'Unlimited workspaces'] }
    end

    trait :enterprise do
      name { 'Enterprise' }
      amount_cents { 49900 } # $499
      trial_period_days { 30 }
      features { ['Unlimited requests', 'Dedicated support', 'Custom integrations'] }
    end

    trait :annual do
      interval { 'year' }
      amount_cents { amount_cents * 10 } # ~2 months free
    end

    trait :inactive do
      active { false }
    end
  end

  # Product factory for one-time purchases and metered billing
  factory :product do
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.sentence }
    amount_cents { rand(500..5000) }
    currency { 'usd' }
    product_type { 'one_time' }
    stripe_id { "prod_#{SecureRandom.hex(8)}" }
    metadata { {} }

    trait :credits_pack do
      name { 'AI Credits Pack' }
      amount_cents { 1900 }
      metadata { { credits: 1000 } }
    end

    trait :setup_service do
      name { 'Setup Service' }
      amount_cents { 49900 }
      metadata { { service_hours: 2 } }
    end

    trait :metered do
      product_type { 'metered' }
      amount_cents { 5 } # $0.05 per unit
      billing_scheme { 'per_unit' }
      metadata { { unit: 'api_request' } }
    end

    trait :premium_metered do
      product_type { 'metered' }
      amount_cents { 10 } # $0.10 per unit
      billing_scheme { 'per_unit' }
      metadata { { unit: 'premium_request' } }
    end
  end

  # Subscription factory
  factory :subscription do
    user
    plan
    status { 'active' }
    stripe_id { "sub_#{SecureRandom.hex(8)}" }
    current_period_start { 1.week.ago }
    current_period_end { 3.weeks.from_now }
    cancel_at_period_end { false }

    trait :trialing do
      status { 'trialing' }
      trial_start { 1.week.ago }
      trial_end { 1.week.from_now }
    end

    trait :past_due do
      status { 'past_due' }
    end

    trait :canceled do
      status { 'canceled' }
      canceled_at { Time.current }
      cancel_at_period_end { true }
    end

    trait :unpaid do
      status { 'unpaid' }
    end

    trait :with_trial do
      trial_start { 2.weeks.ago }
      trial_end { 1.week.ago }
    end

    trait :canceling_at_period_end do
      cancel_at_period_end { true }
      canceled_at { Time.current }
    end
  end

  # Coupon factory
  factory :coupon do
    name { Faker::Lorem.word.upcase }
    description { Faker::Lorem.sentence }
    stripe_id { "coup_#{SecureRandom.hex(6)}" }
    active { true }
    max_redemptions { 100 }
    metadata { {} }

    trait :percentage_discount do
      percent_off { rand(10..50) }
      duration { 'once' }
    end

    trait :fixed_discount do
      amount_off_cents { rand(500..2000) }
      currency { 'usd' }
      duration { 'once' }
    end

    trait :repeating do
      percent_off { 25 }
      duration { 'repeating' }
      duration_in_months { 3 }
    end

    trait :forever do
      percent_off { 15 }
      duration { 'forever' }
    end

    trait :welcome_offer do
      name { 'WELCOME50' }
      percent_off { 50 }
      duration { 'once' }
      metadata { { campaign: 'welcome' } }
    end

    trait :student_discount do
      name { 'STUDENT' }
      amount_off_cents { 1000 }
      currency { 'usd' }
      duration { 'forever' }
      metadata { { requires_verification: true } }
    end

    trait :expired do
      redeem_by { 1.week.ago }
    end

    trait :max_redemptions_reached do
      max_redemptions { 1 }
      times_redeemed { 1 }
    end
  end

  # Usage Record factory (for metered billing)
  factory :usage_record do
    subscription
    product { build(:product, :metered) }
    quantity { rand(10..100) }
    timestamp { Time.current.beginning_of_day }
    recorded_at { Time.current }

    trait :api_usage do
      product { build(:product, :metered, metadata: { unit: 'api_request' }) }
      quantity { rand(50..500) }
    end

    trait :premium_usage do
      product { build(:product, :premium_metered) }
      quantity { rand(5..50) }
    end

    trait :heavy_usage do
      quantity { rand(1000..5000) }
    end

    trait :yesterday do
      timestamp { 1.day.ago.beginning_of_day }
      recorded_at { 1.day.ago.end_of_day }
    end
  end

  # Invoice factory (if needed)
  factory :invoice do
    user
    subscription
    stripe_id { "in_#{SecureRandom.hex(8)}" }
    amount_due_cents { rand(1000..10000) }
    currency { 'usd' }
    status { 'paid' }
    invoice_date { Time.current }

    trait :pending do
      status { 'pending' }
      amount_paid_cents { 0 }
    end

    trait :failed do
      status { 'failed' }
      amount_paid_cents { 0 }
    end

    trait :draft do
      status { 'draft' }
    end
  end
end