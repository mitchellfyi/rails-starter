# frozen_string_literal: true

FactoryBot.define do
  factory :llm_job do
    prompt_template
    user
    workspace
    model { 'gpt-3.5-turbo' }
    context { { name: 'John', topic: 'AI' } }
    status { 'completed' }
    input_tokens { 150 }
    output_tokens { 300 }
    
    trait :pending do
      status { 'pending' }
      input_tokens { nil }
      output_tokens { nil }
    end
    
    trait :processing do
      status { 'processing' }
    end
    
    trait :failed do
      status { 'failed' }
      error_message { 'API rate limit exceeded' }
    end
    
    trait :with_output do
      after(:create) do |job|
        create(:llm_output, llm_job: job)
      end
    end
  end
end