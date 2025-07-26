# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    workspace
    stripe_invoice_id { "in_#{SecureRandom.hex(8)}" }
    amount_due { 2999 }
    amount_paid { 2999 }
    status { 'paid' }
    invoice_date { 1.week.ago }
    due_date { 2.weeks.from_now }
    
    trait :unpaid do
      status { 'open' }
      amount_paid { 0 }
    end
    
    trait :overdue do
      status { 'open' }
      amount_paid { 0 }
      due_date { 1.week.ago }
    end
    
    trait :draft do
      status { 'draft' }
      amount_paid { 0 }
    end
  end
end