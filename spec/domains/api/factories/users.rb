# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    
    # Add other user attributes as needed based on your User model
    trait :admin do
      # Define admin-specific attributes if needed
    end
  end
end