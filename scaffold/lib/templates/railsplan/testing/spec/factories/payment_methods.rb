# frozen_string_literal: true

FactoryBot.define do
  factory :payment_method do
    workspace
    stripe_payment_method_id { "pm_#{SecureRandom.hex(8)}" }
    card_brand { 'visa' }
    card_last4 { '4242' }
    is_default { true }
    
    trait :amex do
      card_brand { 'amex' }
      card_last4 { '0005' }
    end
    
    trait :mastercard do
      card_brand { 'mastercard' }
      card_last4 { '4444' }
    end
    
    trait :non_default do
      is_default { false }
    end
  end
end