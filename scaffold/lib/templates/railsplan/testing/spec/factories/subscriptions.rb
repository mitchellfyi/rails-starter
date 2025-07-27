# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    workspace
    stripe_subscription_id { "sub_#{SecureRandom.hex(8)}" }
    status { 'active' }
    current_period_start { 1.month.ago }
    current_period_end { 1.month.from_now }
    plan_name { 'Pro Plan' }
    plan_amount { 2999 } # $29.99 in cents
    
    trait :trialing do
      status { 'trialing' }
      trial_end { 2.weeks.from_now }
    end
    
    trait :past_due do
      status { 'past_due' }
    end
    
    trait :canceled do
      status { 'canceled' }
      canceled_at { 1.week.ago }
    end
    
    trait :incomplete do
      status { 'incomplete' }
    end
  end
end