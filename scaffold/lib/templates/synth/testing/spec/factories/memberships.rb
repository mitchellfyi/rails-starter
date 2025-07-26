# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    workspace
    role { 'member' }
    
    trait :owner do
      role { 'owner' }
    end
    
    trait :admin do
      role { 'admin' }
    end
  end
end