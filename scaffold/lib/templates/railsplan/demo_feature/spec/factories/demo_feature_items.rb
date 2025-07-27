# frozen_string_literal: true

FactoryBot.define do
  factory :demo_feature_item, class: 'DemoFeatureItem' do
    association :user
    name { Faker::Lorem.words(number: 2).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    active { true }
    metadata { {} }

    trait :inactive do
      active { false }
    end

    trait :without_description do
      description { nil }
    end

    trait :with_metadata do
      metadata { { category: 'test', priority: 'high' } }
    end
  end
end
