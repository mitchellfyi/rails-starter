# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    confirmed_at { Time.current }
    
    trait :admin do
      after(:create) do |user|
        # Add admin flag or role depending on implementation
        user.update_attribute(:admin, true) if user.respond_to?(:admin)
      end
    end
    
    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end