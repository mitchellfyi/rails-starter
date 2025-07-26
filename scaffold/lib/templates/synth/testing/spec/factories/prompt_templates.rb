# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_template do
    name { Faker::Lorem.words(2).join('_') }
    content { 'Hello {{name}}, how are you today?' }
    version { '1.0.0' }
    output_format { 'text' }
    tags { %w[greeting personal] }
    active { true }
    
    trait :with_json_output do
      content { '{"greeting": "Hello {{name}}", "question": "How are you?"}' }
      output_format { 'json' }
    end
    
    trait :with_markdown_output do
      content { '# Hello {{name}}\n\nHow are you today?\n\n- Option 1\n- Option 2' }
      output_format { 'markdown' }
    end
    
    trait :inactive do
      active { false }
    end
  end
end