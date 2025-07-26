# frozen_string_literal: true

FactoryBot.define do
  factory :feature_flag do
    name { 'new_dashboard' }
    enabled { true }
    description { 'Enable the new dashboard interface' }
    rollout_percentage { 100 }
    
    trait :disabled do
      enabled { false }
    end
    
    trait :partial_rollout do
      rollout_percentage { 25 }
    end
    
    trait :user_specific do
      rollout_percentage { 0 }
      user_ids { [1, 2, 3] }
    end
  end
end