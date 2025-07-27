# frozen_string_literal: true

# Create default AI providers
puts "Creating AI providers..."

openai = AiProvider.find_or_create_by(slug: 'openai') do |provider|
  provider.name = 'OpenAI'
  provider.description = 'OpenAI GPT models including GPT-4, GPT-3.5-turbo'
  provider.api_base_url = 'https://api.openai.com'
  provider.supported_models = [
    'gpt-4',
    'gpt-4-turbo-preview',
    'gpt-4-0125-preview',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-16k'
  ]
  provider.default_config = {
    temperature: 0.7,
    max_tokens: 4096,
    top_p: 1.0,
    frequency_penalty: 0.0,
    presence_penalty: 0.0
  }
  provider.priority = 0
  provider.active = true
end

anthropic = AiProvider.find_or_create_by(slug: 'anthropic') do |provider|
  provider.name = 'Anthropic'
  provider.description = 'Anthropic Claude models'
  provider.api_base_url = 'https://api.anthropic.com'
  provider.supported_models = [
    'claude-3-opus-20240229',
    'claude-3-sonnet-20240229',
    'claude-3-haiku-20240307',
    'claude-2.1',
    'claude-2.0'
  ]
  provider.default_config = {
    temperature: 0.7,
    max_tokens: 4096,
    top_p: 1.0
  }
  provider.priority = 1
  provider.active = true
end

cohere = AiProvider.find_or_create_by(slug: 'cohere') do |provider|
  provider.name = 'Cohere'
  provider.description = 'Cohere Command models'
  provider.api_base_url = 'https://api.cohere.ai'
  provider.supported_models = [
    'command',
    'command-light',
    'command-nightly',
    'command-light-nightly'
  ]
  provider.default_config = {
    temperature: 0.7,
    max_tokens: 4096,
    k: 0,
    p: 1.0,
    frequency_penalty: 0.0,
    presence_penalty: 0.0
  }
  provider.priority = 2
  provider.active = true
end

puts "✅ Created #{AiProvider.count} AI providers"
puts "  - #{openai.name} (#{openai.supported_models.size} models)"
puts "  - #{anthropic.name} (#{anthropic.supported_models.size} models)"
puts "  - #{cohere.name} (#{cohere.supported_models.size} models)"