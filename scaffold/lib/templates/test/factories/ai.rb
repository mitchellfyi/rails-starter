# frozen_string_literal: true

# AI Module Factories
# Factories for prompt templates, LLM jobs, and outputs

FactoryBot.define do
  # Prompt Template factory
  factory :prompt_template do
    name { Faker::Lorem.words(number: 2).join('_') }
    description { Faker::Lorem.sentence }
    content { "Hello {{name}}, welcome to {{workspace_name}}. How can I help you with {{task}}?" }
    tags { [Faker::Lorem.word, Faker::Lorem.word] }
    variables { ['name', 'workspace_name', 'task'] }
    output_format { 'text' }
    version { 1 }
    workspace

    trait :json_output do
      output_format { 'json' }
      content { 'Generate JSON with: {"name": "{{name}}", "response": "{{response}}"}' }
    end

    trait :markdown_output do
      output_format { 'markdown' }
      content { "# {{title}}\n\n{{content}}\n\n## Summary\n{{summary}}" }
    end

    trait :code_review do
      name { 'code_review' }
      tags { ['code-review', 'development'] }
      content { "Review this {{language}} code:\n\n```{{language}}\n{{code}}\n```\n\nFocus on: {{focus_areas}}" }
      variables { ['language', 'code', 'focus_areas'] }
    end

    trait :with_long_content do
      content { Faker::Lorem.paragraphs(number: 5).join("\n\n") + " Variables: {{var1}}, {{var2}}" }
      variables { ['var1', 'var2'] }
    end
  end

  # LLM Job factory
  factory :llm_job do
    prompt_template
    user
    workspace
    model { 'gpt-4' }
    context { { name: 'John', workspace_name: 'Test Workspace', task: 'testing' }.to_json }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
      started_at { 1.hour.ago }
      completed_at { 1.hour.ago + 5.seconds }

      after(:create) do |job|
        create(:llm_output, llm_job: job)
      end
    end

    trait :failed do
      status { 'failed' }
      started_at { 1.hour.ago }
      failed_at { 1.hour.ago + 10.seconds }
      error_message { 'Rate limit exceeded' }
      retry_count { 3 }
    end

    trait :running do
      status { 'running' }
      started_at { 5.minutes.ago }
    end

    trait :with_retries do
      retry_count { 2 }
      error_message { 'Temporary service unavailable' }
    end

    trait :gpt_3_5 do
      model { 'gpt-3.5-turbo' }
    end

    trait :claude do
      model { 'claude-3-sonnet' }
    end
  end

  # LLM Output factory
  factory :llm_output do
    llm_job
    content { Faker::Lorem.paragraph(sentence_count: 3) }
    tokens_used { rand(50..500) }
    cost_cents { tokens_used * 0.1 } # Rough estimate

    trait :with_positive_feedback do
      feedback_rating { 1 } # thumbs up
      feedback_comment { 'Great response!' }
    end

    trait :with_negative_feedback do
      feedback_rating { -1 } # thumbs down
      feedback_comment { 'Could be better, too generic.' }
    end

    trait :json_content do
      content { { result: 'success', data: Faker::Lorem.words(number: 5) }.to_json }
    end

    trait :code_content do
      content do
        <<~CODE
          def example_method(param)
            # #{Faker::Lorem.sentence}
            return param.capitalize if param.is_a?(String)
            param
          end
        CODE
      end
    end

    trait :long_content do
      content { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
      tokens_used { rand(1000..2000) }
      cost_cents { tokens_used * 0.1 }
    end

    trait :expensive do
      tokens_used { rand(3000..5000) }
      cost_cents { tokens_used * 0.15 } # Premium model pricing
    end
  end

  # Context Provider factory (if the model exists)
  factory :context_provider do
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    provider_type { 'database' }
    config { { query: 'SELECT * FROM users WHERE active = true' }.to_json }
    active { true }
    workspace

    trait :api_provider do
      provider_type { 'api' }
      config { { url: 'https://api.example.com/data', headers: { 'Authorization' => 'Bearer token' } }.to_json }
    end

    trait :file_provider do
      provider_type { 'file' }
      config { { path: '/uploads/documents', file_types: ['pdf', 'txt'] }.to_json }
    end

    trait :inactive do
      active { false }
    end
  end
end