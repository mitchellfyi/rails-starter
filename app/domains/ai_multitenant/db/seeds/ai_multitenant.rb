# frozen_string_literal: true

# AI Multitenant Module Seeds
# This file seeds default AI providers and sample prompt templates

puts "🤖 Seeding AI Multitenant module..."

# Create default AI providers
providers_data = [
  {
    name: 'OpenAI',
    slug: 'openai',
    description: 'OpenAI GPT models including GPT-3.5 and GPT-4 series',
    api_base_url: 'https://api.openai.com/v1',
    supported_models: [
      'gpt-3.5-turbo',
      'gpt-3.5-turbo-16k',
      'gpt-4',
      'gpt-4-turbo',
      'gpt-4-turbo-preview',
      'gpt-4o',
      'gpt-4o-mini'
    ],
    default_config: {
      temperature: 0.7,
      max_tokens: 4096,
      top_p: 1.0,
      frequency_penalty: 0.0,
      presence_penalty: 0.0
    },
    priority: 1,
    active: true
  },
  {
    name: 'Anthropic',
    slug: 'anthropic',
    description: 'Anthropic Claude models for advanced reasoning and analysis',
    api_base_url: 'https://api.anthropic.com/v1',
    supported_models: [
      'claude-3-haiku-20240307',
      'claude-3-sonnet-20240229',
      'claude-3-opus-20240229',
      'claude-3-5-sonnet-20240620'
    ],
    default_config: {
      temperature: 0.7,
      max_tokens: 4096,
      top_p: 1.0,
      top_k: 40
    },
    priority: 2,
    active: true
  },
  {
    name: 'Cohere',
    slug: 'cohere',
    description: 'Cohere Command models for enterprise applications',
    api_base_url: 'https://api.cohere.ai/v1',
    supported_models: [
      'command',
      'command-nightly',
      'command-light',
      'command-light-nightly'
    ],
    default_config: {
      temperature: 0.7,
      max_tokens: 4096,
      k: 0,
      p: 0.75
    },
    priority: 3,
    active: true
  }
]

providers_data.each do |provider_data|
  provider = AiProvider.find_or_create_by(slug: provider_data[:slug]) do |p|
    p.name = provider_data[:name]
    p.description = provider_data[:description]
    p.api_base_url = provider_data[:api_base_url]
    p.supported_models = provider_data[:supported_models]
    p.default_config = provider_data[:default_config]
    p.priority = provider_data[:priority]
    p.active = provider_data[:active]
  end

  if provider.persisted?
    puts "✅ Created/Updated AI provider: #{provider.name}"
  else
    puts "❌ Failed to create AI provider: #{provider.name} - #{provider.errors.full_messages.join(', ')}"
  end
end

# Create sample prompt templates (global/public templates)
sample_templates = [
  {
    name: 'Email Summary',
    slug: 'email_summary',
    description: 'Generate a concise summary of an email or message',
    prompt_body: 'Please provide a brief summary of the following email or message:\n\n{{content}}\n\nSummary:',
    output_format: 'text',
    tags: ['email', 'summary', 'communication'],
    is_public: true
  },
  {
    name: 'Code Review',
    slug: 'code_review',
    description: 'Review code and provide feedback on improvements',
    prompt_body: 'Please review the following {{language}} code and provide feedback on:\n1. Code quality and best practices\n2. Potential bugs or issues\n3. Suggestions for improvement\n\nCode:\n```{{language}}\n{{code}}\n```',
    output_format: 'markdown',
    tags: ['code', 'review', 'development'],
    is_public: true
  },
  {
    name: 'Meeting Notes',
    slug: 'meeting_notes',
    description: 'Generate structured meeting notes from transcript or summary',
    prompt_body: 'Convert the following meeting transcript into structured meeting notes:\n\n{{transcript}}\n\nPlease format as:\n- **Attendees**: \n- **Key Discussion Points**: \n- **Decisions Made**: \n- **Action Items**: \n- **Next Steps**: ',
    output_format: 'markdown',
    tags: ['meeting', 'notes', 'productivity'],
    is_public: true
  },
  {
    name: 'Content Ideas',
    slug: 'content_ideas',
    description: 'Generate content ideas for a specific topic or audience',
    prompt_body: 'Generate 10 creative content ideas for {{topic}} targeting {{audience}}. For each idea, provide:\n1. A catchy title\n2. Brief description (1-2 sentences)\n3. Content format (blog post, video, infographic, etc.)\n\nTopic: {{topic}}\nTarget Audience: {{audience}}\nTone: {{tone}}',
    output_format: 'markdown',
    tags: ['content', 'marketing', 'ideas'],
    is_public: true
  },
  {
    name: 'API Documentation',
    slug: 'api_documentation',
    description: 'Generate API documentation from endpoint description',
    prompt_body: 'Generate comprehensive API documentation for the following endpoint:\n\n**Endpoint**: {{method}} {{path}}\n**Description**: {{description}}\n**Parameters**: {{parameters}}\n\nPlease include:\n- Endpoint description\n- Request format\n- Response format\n- Example request/response\n- Error codes\n- Authentication requirements',
    output_format: 'markdown',
    tags: ['api', 'documentation', 'development'],
    is_public: true
  },
  {
    name: 'Customer Support Response',
    slug: 'customer_support',
    description: 'Generate helpful customer support responses',
    prompt_body: 'Generate a helpful and professional customer support response for the following inquiry:\n\n**Customer Issue**: {{issue}}\n**Product/Service**: {{product}}\n**Customer Tone**: {{tone}}\n\nResponse should be:\n- Empathetic and understanding\n- Solution-focused\n- Professional but friendly\n- Include next steps if applicable',
    output_format: 'text',
    tags: ['support', 'customer', 'communication'],
    is_public: true
  },
  {
    name: 'SQL Query Generator',
    slug: 'sql_query',
    description: 'Generate SQL queries from natural language descriptions',
    prompt_body: 'Generate a SQL query for the following request:\n\n**Database**: {{database_type}}\n**Tables**: {{tables}}\n**Request**: {{request}}\n\nPlease provide:\n1. The SQL query\n2. Brief explanation of what the query does\n3. Any assumptions made about table structure',
    output_format: 'markdown',
    tags: ['sql', 'database', 'development'],
    is_public: true
  }
]

sample_templates.each do |template_data|
  template = PromptTemplate.find_or_create_by(slug: template_data[:slug]) do |t|
    t.name = template_data[:name]
    t.description = template_data[:description]
    t.prompt_body = template_data[:prompt_body]
    t.output_format = template_data[:output_format]
    t.tags = template_data[:tags]
    t.is_public = template_data[:is_public]
    t.active = true
  end

  if template.persisted?
    puts "✅ Created/Updated prompt template: #{template.name}"
  else
    puts "❌ Failed to create prompt template: #{template.name} - #{template.errors.full_messages.join(', ')}"
  end
end

# If there are workspaces and OpenAI API key is available, create a sample credential
if defined?(Workspace) && Workspace.exists? && ENV['OPENAI_API_KEY'].present?
  openai_provider = AiProvider.find_by(slug: 'openai')
  
  if openai_provider
    # Create credentials for each workspace
    Workspace.limit(3).each do |workspace|
      next if workspace.ai_credentials.where(ai_provider: openai_provider).exists?

      credential = workspace.ai_credentials.create(
        ai_provider: openai_provider,
        name: 'Default OpenAI',
        api_key: ENV['OPENAI_API_KEY'],
        preferred_model: 'gpt-4o-mini',
        temperature: 0.7,
        max_tokens: 4096,
        is_default: true,
        active: true
      )

      if credential.persisted?
        puts "✅ Created default OpenAI credential for workspace: #{workspace.name}"
        
        # Test the credential
        test_result = credential.test_connection
        if test_result[:success]
          puts "✅ OpenAI credential test passed for workspace: #{workspace.name}"
        else
          puts "⚠️  OpenAI credential test failed for workspace: #{workspace.name} - #{test_result[:error]}"
        end
      else
        puts "❌ Failed to create OpenAI credential for workspace: #{workspace.name} - #{credential.errors.full_messages.join(', ')}"
      end
    end
  end
elsif ENV['OPENAI_API_KEY'].blank?
  puts "⚠️  OPENAI_API_KEY not set - skipping credential creation"
  puts "   Set OPENAI_API_KEY environment variable to automatically create workspace credentials"
else
  puts "⚠️  No workspaces found - skipping credential creation"
end

puts ""
puts "🎉 AI Multitenant module seeding completed!"
puts ""
puts "Next steps:"
puts "1. Set your AI provider API keys in environment variables:"
puts "   - OPENAI_API_KEY for OpenAI"
puts "   - ANTHROPIC_API_KEY for Anthropic"
puts "   - COHERE_API_KEY for Cohere"
puts ""
puts "2. Visit /ai/playground to test the AI playground"
puts "3. Configure AI credentials for your workspaces at /ai/credentials"
puts "4. Set up the daily usage summary cron job:"
puts "   whenever --update-crontab"
puts ""
puts "Available AI providers:"
AiProvider.active.each do |provider|
  puts "  • #{provider.name} (#{provider.supported_models.size} models)"
end

puts ""
puts "Available prompt templates:"
PromptTemplate.where(is_public: true, active: true).each do |template|
  puts "  • #{template.name}: #{template.description}"
end