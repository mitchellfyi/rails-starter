# frozen_string_literal: true

FactoryBot.define do
  factory :workspace do
    name { Faker::Company.name }
    slug { Faker::Internet.slug(words: name.split, glue: '-') }
    
    trait :with_owner do
      after(:create) do |workspace|
        user = create(:user)
        create(:membership, workspace: workspace, user: user, role: 'owner')
      end
    end
  end
end