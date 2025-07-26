# frozen_string_literal: true

# CMS Module Seeds
# Creates sample blog posts with metadata for the CMS/blog engine

puts "   📄 Creating sample blog posts..."

# Welcome blog post
welcome_post = find_or_create_by_with_attributes(
  Post,
  { slug: 'welcome-to-your-new-ai-saas' },
  {
    title: 'Welcome to Your New AI-Powered SaaS',
    excerpt: 'Learn how to get the most out of your new Rails SaaS starter template with built-in AI capabilities.',
    content: <<~CONTENT.strip,
      # Welcome to Your New AI-Powered SaaS

      Congratulations on setting up your new Rails SaaS application! This starter template provides everything you need to build a modern, AI-native software-as-a-service product.

      ## What's Included

      This template comes with:

      - **Authentication & Authorization**: Secure user management with Devise and Pundit
      - **Multi-tenancy**: Workspace-based organization with role management
      - **AI Integration**: Prompt templates and asynchronous LLM job processing
      - **Billing System**: Stripe integration with subscriptions, one-time purchases, and metered billing
      - **Background Jobs**: Sidekiq for reliable job processing
      - **Modern Frontend**: Hotwire (Turbo + Stimulus) with TailwindCSS

      ## Getting Started

      1. **Explore the Demo Data**: We've created sample prompt templates, AI jobs, and billing plans for you to explore
      2. **Configure Your Environment**: Set up your API keys for OpenAI, Stripe, and other services
      3. **Customize Your App**: Modify the templates and add your own features
      4. **Deploy**: Use the included deployment configurations for Fly.io, Render, or Kamal

      ## AI Capabilities

      The AI module provides:

      - **Prompt Templates**: Create reusable prompts with variable interpolation
      - **Asynchronous Processing**: Run LLM requests in the background with Sidekiq
      - **Context Providers**: Fetch dynamic data to enrich your prompts
      - **Output Management**: Store, version, and get feedback on AI outputs

      ## Need Help?

      Check out the documentation in each module's README file, or explore the example data we've created for you.

      Happy building! 🚀
    CONTENT
    status: 'published',
    published_at: 3.days.ago,
    author: demo_user,
    workspace: demo_workspace,
    tags: ['welcome', 'getting-started', 'ai', 'saas'],
    meta_title: 'Welcome to Your New AI-Powered SaaS | Rails Starter',
    meta_description: 'Get started with your new Rails SaaS template featuring AI integration, billing, and modern development tools.',
    featured_image_url: 'https://images.unsplash.com/photo-1555421689-491a97ff2040?w=1200&h=600&fit=crop',
    reading_time_minutes: 3,
    view_count: 42
  }
)

# Technical deep-dive post
technical_post = find_or_create_by_with_attributes(
  Post,
  { slug: 'building-ai-workflows-with-prompt-templates' },
  {
    title: 'Building Effective AI Workflows with Prompt Templates',
    excerpt: 'Learn how to create, manage, and optimize prompt templates for consistent AI outputs in your SaaS application.',
    content: <<~CONTENT.strip,
      # Building Effective AI Workflows with Prompt Templates

      One of the most powerful features of this Rails SaaS template is the prompt template system. It allows you to create reusable, parameterized prompts that can be executed asynchronously with different contexts.

      ## Why Prompt Templates Matter

      Rather than hardcoding prompts in your application code, prompt templates provide:

      - **Reusability**: Write once, use many times with different parameters
      - **Version Control**: Track changes and improvements over time
      - **Collaboration**: Non-technical team members can modify prompts
      - **A/B Testing**: Compare different prompt versions for effectiveness

      ## Creating Your First Template

      Here's an example of a simple prompt template:

      ```ruby
      PromptTemplate.create!(
        name: 'product_description',
        content: 'Write a compelling product description for {{product_name}}. 
                  Target audience: {{audience}}. 
                  Key features: {{features}}. 
                  Tone: {{tone}}',
        variables: ['product_name', 'audience', 'features', 'tone'],
        tags: ['marketing', 'content'],
        output_format: 'markdown'
      )
      ```

      ## Variable Interpolation

      The template system supports several types of variables:

      - **Simple substitution**: `{{variable_name}}`
      - **Conditional content**: `{{#if variable}}content{{/if}}`
      - **Loops**: `{{#each items}}{{name}}{{/each}}`
      - **Filters**: `{{variable_name | capitalize}}`

      ## Executing Templates

      Templates are executed asynchronously using the LLM job system:

      ```ruby
      job = LLMJob.perform_later(
        template: template,
        context: {
          product_name: 'AI Assistant Pro',
          audience: 'software developers',
          features: 'real-time responses, custom integrations, analytics',
          tone: 'professional yet approachable'
        },
        model: 'gpt-4'
      )
      ```

      ## Best Practices

      1. **Keep prompts focused**: One template should do one thing well
      2. **Use clear variable names**: Make it obvious what each variable represents
      3. **Provide examples**: Include sample outputs in your template descriptions
      4. **Version carefully**: Test new versions before deploying to production
      5. **Tag appropriately**: Use consistent tagging for easy discovery

      ## Advanced Features

      The system also supports:

      - **Context providers**: Automatically fetch data for your templates
      - **Output validation**: Ensure AI responses meet your requirements
      - **Feedback loops**: Collect user feedback to improve templates over time
      - **Rate limiting**: Prevent excessive API usage

      Start experimenting with the example templates we've provided, and build your own AI workflows from there!
    CONTENT
    status: 'published',
    published_at: 1.day.ago,
    author: demo_user,
    workspace: demo_workspace,
    tags: ['ai', 'prompt-templates', 'technical', 'workflow'],
    meta_title: 'Building AI Workflows with Prompt Templates | Technical Guide',
    meta_description: 'Learn how to create effective prompt templates for consistent AI outputs in your Rails SaaS application.',
    featured_image_url: 'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=1200&h=600&fit=crop',
    reading_time_minutes: 6,
    view_count: 128
  }
)

# Business-focused post
business_post = find_or_create_by_with_attributes(
  Post,
  { slug: 'pricing-your-ai-saas-lessons-learned' },
  {
    title: 'Pricing Your AI SaaS: Lessons Learned from Real Deployments',
    excerpt: 'Insights on pricing strategies, billing models, and customer psychology for AI-powered SaaS products.',
    content: <<~CONTENT.strip,
      # Pricing Your AI SaaS: Lessons Learned from Real Deployments

      Pricing an AI-powered SaaS product presents unique challenges. Unlike traditional software, your costs are variable and tied to AI model usage. Here's what we've learned from real deployments.

      ## The Challenge of Variable Costs

      Traditional SaaS products have relatively fixed costs per customer. AI SaaS products face:

      - **Variable AI model costs**: GPT-4 requests cost more than GPT-3.5
      - **Usage unpredictability**: Some customers generate 10x more requests than others
      - **Model pricing changes**: AI providers regularly adjust their pricing

      ## Pricing Models That Work

      We've seen success with these approaches:

      ### 1. Hybrid Freemium + Usage Tiers

      - **Free tier**: Limited requests (100/month) to demonstrate value
      - **Starter tier**: Fixed monthly fee with request allowance (1,000 requests)
      - **Professional tier**: Higher allowance with overage billing
      - **Enterprise**: Unlimited with premium support

      ### 2. Value-Based Pricing

      Price based on the value delivered, not just costs:

      - **Content generation**: Price per blog post or marketing copy created
      - **Code review**: Price per pull request analyzed
      - **Customer support**: Price per support ticket handled

      ### 3. Seat + Usage Hybrid

      - Base price per user/seat
      - Additional charges for heavy AI usage
      - Works well for team-based products

      ## Implementation in This Template

      This starter template includes billing infrastructure for all these models:

      ```ruby
      # Subscription plans with request allowances
      Plan.create!(
        name: 'Professional',
        amount_cents: 9900,
        features: ['10,000 AI requests/month', 'Priority support']
      )

      # Metered billing for overages
      Product.create!(
        name: 'Additional AI Requests',
        amount_cents: 5, # $0.05 per request
        product_type: 'metered'
      )

      # One-time purchases for credits
      Product.create!(
        name: 'AI Credits Pack',
        amount_cents: 1900,
        metadata: { credits: 1000 }
      )
      ```

      ## Psychological Pricing Factors

      ### Transparency Builds Trust

      Be upfront about:
      - How requests are counted
      - What triggers additional charges
      - Cost estimates for typical usage

      ### Generous Free Tiers Drive Adoption

      Our data shows that generous free tiers (100+ requests) lead to:
      - 3x higher conversion rates
      - Better product feedback
      - Stronger word-of-mouth growth

      ### Enterprise Needs Custom Pricing

      Large customers want:
      - Predictable monthly costs
      - Volume discounts
      - Custom integrations included

      ## Monitoring and Optimization

      Track these metrics:

      - **Customer Acquisition Cost (CAC)** vs **Lifetime Value (LTV)**
      - **Usage patterns** by plan tier
      - **Churn rates** when hitting usage limits
      - **Support ticket volume** related to billing

      ## Conclusion

      Pricing AI SaaS products requires balancing customer value, cost management, and growth goals. Start simple, measure everything, and iterate based on real usage data.

      The billing system in this template gives you the flexibility to experiment with different models as you learn what works for your specific product and market.
    CONTENT
    status: 'published',
    published_at: 5.days.ago,
    author: demo_user,
    workspace: demo_workspace,
    tags: ['pricing', 'business', 'saas', 'ai', 'billing'],
    meta_title: 'AI SaaS Pricing Strategies: Lessons from Real Deployments',
    meta_description: 'Learn effective pricing strategies for AI-powered SaaS products, including freemium, usage-based, and hybrid billing models.',
    featured_image_url: 'https://images.unsplash.com/photo-1553729459-efe14ef6055d?w=1200&h=600&fit=crop',
    reading_time_minutes: 8,
    view_count: 89
  }
)

# Draft post (for testing different post states)
draft_post = find_or_create_by_with_attributes(
  Post,
  { slug: 'upcoming-ai-features-roadmap' },
  {
    title: 'Upcoming AI Features: Our 2024 Roadmap',
    excerpt: 'A preview of the exciting AI capabilities we are building for the Rails SaaS starter template.',
    content: <<~CONTENT.strip,
      # Upcoming AI Features: Our 2024 Roadmap

      We're constantly improving the AI capabilities of this Rails SaaS starter template. Here's what's coming in 2024.

      ## Q1 2024: Enhanced Context Providers

      - **Database context provider**: Automatically pull relevant data from your database
      - **File context provider**: Process and include content from uploaded documents
      - **API context providers**: Integrate with external services like GitHub, Slack, and CRMs

      ## Q2 2024: Advanced Prompt Management

      - **Prompt versioning UI**: Visual diff tool for comparing prompt versions
      - **A/B testing framework**: Split test different prompts automatically
      - **Prompt marketplace**: Share and discover prompt templates with the community

      ## Q3 2024: Multi-Modal AI

      - **Image generation**: Integration with DALL-E and Midjourney
      - **Document processing**: Extract text and insights from PDFs, images, and documents
      - **Audio processing**: Transcription and analysis capabilities

      ## Q4 2024: Enterprise Features

      - **Custom model hosting**: Support for self-hosted models
      - **Advanced analytics**: Detailed usage analytics and cost optimization
      - **Workflow automation**: Visual prompt chaining and automation tools

      Stay tuned for updates!
    CONTENT
    status: 'draft',
    author: demo_user,
    workspace: demo_workspace,
    tags: ['roadmap', 'features', 'ai'],
    meta_title: 'AI Features Roadmap 2024 | Rails SaaS Starter',
    meta_description: 'Preview upcoming AI features including enhanced context providers, multi-modal AI, and enterprise capabilities.',
    reading_time_minutes: 4
  }
)

# Create some categories if the model exists
if defined?(Category)
  puts "   📂 Creating content categories..."
  
  tech_category = find_or_create_by_with_attributes(
    Category,
    { slug: 'technical' },
    {
      name: 'Technical',
      description: 'Deep-dive technical articles about AI, Rails, and software development'
    }
  )
  
  business_category = find_or_create_by_with_attributes(
    Category,
    { slug: 'business' },
    {
      name: 'Business',
      description: 'Business insights, pricing strategies, and growth tactics for SaaS'
    }
  )
  
  tutorials_category = find_or_create_by_with_attributes(
    Category,
    { slug: 'tutorials' },
    {
      name: 'Tutorials',
      description: 'Step-by-step guides and how-to articles'
    }
  )
  
  # Associate posts with categories
  technical_post.update!(category: tech_category) if technical_post.respond_to?(:category=)
  business_post.update!(category: business_category) if business_post.respond_to?(:category=)
  welcome_post.update!(category: tutorials_category) if welcome_post.respond_to?(:category=)
end

puts "   ✅ CMS module seeding complete"