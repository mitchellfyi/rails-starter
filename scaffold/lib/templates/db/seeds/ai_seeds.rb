# frozen_string_literal: true

# AI Module Seeds
# Creates example prompt templates, LLM jobs, and outputs

# Example prompt templates with variable interpolation and tags
puts "   📝 Creating prompt templates..."

# Basic greeting template
greeting_template = find_or_create_by_with_attributes(
  PromptTemplate,
  { name: 'greeting' },
  {
    description: 'Simple greeting template with name interpolation',
    content: 'Hello {{name}}! Welcome to {{workspace_name}}. How can I help you today?',
    tags: ['greeting', 'onboarding'],
    variables: ['name', 'workspace_name'],
    output_format: 'text',
    version: 1,
    workspace: demo_workspace
  }
)

# Code review template
code_review_template = find_or_create_by_with_attributes(
  PromptTemplate,
  { name: 'code_review' },
  {
    description: 'Template for reviewing code changes with specific focus areas',
    content: <<~PROMPT.strip,
      Please review the following code changes:
      
      ```{{language}}
      {{code}}
      ```
      
      Focus on:
      - {{focus_areas}}
      - Security vulnerabilities
      - Performance implications
      - Code maintainability
      
      Provide feedback in the following format:
      - **Issues Found**: List any problems
      - **Suggestions**: Improvement recommendations  
      - **Overall Rating**: Score from 1-10
    PROMPT
    tags: ['code-review', 'development', 'quality'],
    variables: ['language', 'code', 'focus_areas'],
    output_format: 'markdown',
    version: 1,
    workspace: demo_workspace
  }
)

# Content generation template
content_template = find_or_create_by_with_attributes(
  PromptTemplate,
  { name: 'blog_content' },
  {
    description: 'Generate blog post content on any topic',
    content: <<~PROMPT.strip,
      Write a {{post_length}} blog post about "{{topic}}" for {{audience}}.
      
      Requirements:
      - Tone: {{tone}}
      - Include {{key_points}} as main points
      - Add relevant examples and actionable advice
      - End with a compelling call-to-action
      
      Format the response as JSON with:
      {
        "title": "Blog post title",
        "excerpt": "Brief summary",
        "content": "Full blog post in markdown",
        "tags": ["array", "of", "tags"],
        "estimated_read_time": "X minutes"
      }
    PROMPT
    tags: ['content', 'marketing', 'blog'],
    variables: ['post_length', 'topic', 'audience', 'tone', 'key_points'],
    output_format: 'json',
    version: 1,
    workspace: demo_workspace
  }
)

# Customer support template
support_template = find_or_create_by_with_attributes(
  PromptTemplate,
  { name: 'customer_support' },
  {
    description: 'Template for handling customer support inquiries',
    content: <<~PROMPT.strip,
      Customer Inquiry: {{customer_message}}
      Customer Tier: {{customer_tier}}
      Previous Context: {{previous_context}}
      
      Please provide a helpful response that:
      1. Addresses their specific question or concern
      2. Maintains a {{tone}} tone
      3. Offers specific next steps or solutions
      4. Includes relevant documentation links if needed
      
      If this requires escalation, indicate why and to which team.
    PROMPT
    tags: ['support', 'customer-service'],
    variables: ['customer_message', 'customer_tier', 'previous_context', 'tone'],
    output_format: 'text',
    version: 1,
    workspace: demo_workspace
  }
)

# Create example LLM jobs with outputs and feedback
puts "   🤖 Creating example LLM jobs and outputs..."

# Successful greeting job
greeting_job = find_or_create_by_with_attributes(
  LLMJob,
  { 
    prompt_template: greeting_template,
    context: { name: 'Alice', workspace_name: 'Demo Workspace' }.to_json
  },
  {
    model: 'gpt-4',
    status: 'completed',
    started_at: 2.hours.ago,
    completed_at: 2.hours.ago + 3.seconds,
    user: demo_user,
    workspace: demo_workspace
  }
)

find_or_create_by_with_attributes(
  LLMOutput,
  { llm_job: greeting_job },
  {
    content: 'Hello Alice! Welcome to Demo Workspace. How can I help you today?',
    tokens_used: 25,
    cost_cents: 5,
    feedback_rating: 1, # thumbs up
    feedback_comment: 'Perfect greeting message!'
  }
)

# Code review job with detailed output
code_job = find_or_create_by_with_attributes(
  LLMJob,
  {
    prompt_template: code_review_template,
    context: {
      language: 'ruby',
      code: 'def calculate_total(items)\n  items.sum(&:price)\nend',
      focus_areas: 'Error handling, input validation'
    }.to_json
  },
  {
    model: 'gpt-4',
    status: 'completed',
    started_at: 1.hour.ago,
    completed_at: 1.hour.ago + 8.seconds,
    user: demo_user,
    workspace: demo_workspace
  }
)

find_or_create_by_with_attributes(
  LLMOutput,
  { llm_job: code_job },
  {
    content: <<~REVIEW.strip,
      ## Issues Found
      - No input validation - method will fail if `items` is nil
      - No error handling for items without a `price` method
      - Could raise NoMethodError if items contain nil values
      
      ## Suggestions
      - Add nil check: `return 0 if items.nil? || items.empty?`
      - Use safe navigation: `items.sum { |item| item&.price || 0 }`
      - Consider using `Enumerable#filter_map` for cleaner nil handling
      
      ## Overall Rating
      6/10 - Basic functionality works but needs defensive programming
    REVIEW
    tokens_used: 180,
    cost_cents: 36,
    feedback_rating: 1, # thumbs up
    feedback_comment: 'Very helpful code review!'
  }
)

# Failed job example (for testing error handling)
failed_job = find_or_create_by_with_attributes(
  LLMJob,
  {
    prompt_template: content_template,
    context: { 
      post_length: 'long',
      topic: 'AI in Software Development',
      audience: 'developers',
      tone: 'technical',
      key_points: 'automation, productivity, best practices'
    }.to_json
  },
  {
    model: 'gpt-4',
    status: 'failed',
    started_at: 30.minutes.ago,
    failed_at: 30.minutes.ago + 15.seconds,
    error_message: 'Rate limit exceeded. Please try again later.',
    retry_count: 2,
    user: demo_user,
    workspace: demo_workspace
  }
)

# In-progress job (for testing UI states)
find_or_create_by_with_attributes(
  LLMJob,
  {
    prompt_template: support_template,
    context: {
      customer_message: 'I am having trouble logging into my account',
      customer_tier: 'premium',
      previous_context: 'Customer reported password reset issues yesterday',
      tone: 'empathetic'
    }.to_json
  },
  {
    model: 'gpt-3.5-turbo',
    status: 'running',
    started_at: 5.minutes.ago,
    user: demo_user,
    workspace: demo_workspace
  }
)

puts "   ✅ AI module seeding complete"