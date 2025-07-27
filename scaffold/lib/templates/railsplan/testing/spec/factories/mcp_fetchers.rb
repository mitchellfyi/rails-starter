# frozen_string_literal: true

FactoryBot.define do
  factory :mcp_fetcher do
    name { 'github_user' }
    fetcher_type { 'http' }
    configuration do
      {
        url: 'https://api.github.com/users/{{username}}',
        method: 'GET',
        headers: {
          'Authorization' => 'token {{github_token}}',
          'Accept' => 'application/vnd.github.v3+json'
        }
      }
    end
    active { true }
    
    trait :database_fetcher do
      name { 'user_stats' }
      fetcher_type { 'database' }
      configuration do
        {
          query: 'SELECT count(*) as user_count FROM users WHERE created_at > ?',
          params: ['{{date}}']
        }
      end
    end
    
    trait :file_fetcher do
      name { 'document_parser' }
      fetcher_type { 'file' }
      configuration do
        {
          path: '{{file_path}}',
          format: 'pdf',
          extract: 'text'
        }
      end
    end
    
    trait :inactive do
      active { false }
    end
  end
end