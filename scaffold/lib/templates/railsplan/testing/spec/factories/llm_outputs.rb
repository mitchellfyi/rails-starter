# frozen_string_literal: true

FactoryBot.define do
  factory :llm_output do
    llm_job
    content { 'Hello John, I am doing well, thank you for asking!' }
    format { 'text' }
    feedback_score { nil }
    
    trait :with_positive_feedback do
      feedback_score { 1 }
    end
    
    trait :with_negative_feedback do
      feedback_score { -1 }
    end
    
    trait :json_format do
      content { '{"greeting": "Hello John", "response": "I am doing well!"}' }
      format { 'json' }
    end
    
    trait :markdown_format do
      content { "# Hello John\n\nI am doing well, thank you for asking!\n\n- Great day\n- Ready to help" }
      format { 'markdown' }
    end
  end
end