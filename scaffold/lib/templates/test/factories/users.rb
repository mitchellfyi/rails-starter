# frozen_string_literal: true

# Base factories for the Rails SaaS Starter Template
# These provide consistent test data across the application

FactoryBot.define do
  # User factory with reasonable defaults
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      admin { true }
    end

    trait :with_workspace do
      after(:create) do |user|
        workspace = create(:workspace)
        create(:membership, user: user, workspace: workspace, role: 'admin')
      end
    end
  end

  # Workspace factory
  factory :workspace do
    name { Faker::Company.name }
    slug { Faker::Internet.unique.slug(glue: '-') }
    description { Faker::Company.catch_phrase }

    trait :with_members do
      after(:create) do |workspace|
        3.times do
          user = create(:user)
          create(:membership, user: user, workspace: workspace, role: 'member')
        end
      end
    end
  end

  # Membership factory connecting users to workspaces
  factory :membership do
    user
    workspace
    role { 'member' }

    trait :admin do
      role { 'admin' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end
end