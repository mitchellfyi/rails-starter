# Seeds and Fixtures Usage Guide

This document explains how to use the comprehensive seed data and test fixtures included in the Rails SaaS Starter Template.

## Overview

The template includes:
- **Idempotent seeds** that can be run multiple times safely
- **Comprehensive test factories** for consistent test data
- **Module-specific seeds** that load automatically when modules are installed
- **Demo data** for immediate exploration and development

## Quick Start

After generating your Rails app with the template:

```bash
# Run migrations and seed the database
rails db:migrate
rails db:seed

# Your app now has demo data ready to explore!
```

**Demo Login:**
- Email: `demo@example.com`
- Password: `password123`

## Seed Structure

### Main Seeds (`db/seeds.rb`)
- Creates demo user and workspace
- Loads module-specific seeds automatically
- Provides idempotent helper methods
- Shows progress with clear status messages

### Module Seeds (`db/seeds/`)
- `ai_seeds.rb`: Prompt templates, LLM jobs, and outputs
- `billing_seeds.rb`: Stripe plans, products, and coupons
- `cms_seeds.rb`: Blog posts, categories, and content

## Demo Data Included

### Base Data
- **Demo User**: Confirmed user account for immediate login
- **Demo Workspace**: Sample organization with admin membership

### AI Module Data
- **4 Prompt Templates**: 
  - Greeting template with variable interpolation
  - Code review template with focus areas
  - Content generation with JSON output
  - Customer support with tone customization
- **Example LLM Jobs**: Completed, failed, and running job states
- **AI Outputs**: With feedback ratings and cost tracking

### Billing Module Data
- **Subscription Plans**:
  - Free Trial (14 days, $0)
  - Starter ($29/month)
  - Professional ($99/month, annual options)
  - Enterprise ($499/month)
- **One-time Products**: AI credits, setup services, templates
- **Metered Billing**: Pay-per-API-request products
- **Coupons**: Welcome offers, student discounts, seasonal promotions
- **Demo Subscription**: Active subscription for demo user

### CMS Module Data
- **4 Blog Posts**: Welcome, technical deep-dive, business strategy, draft
- **Categories**: Technical, Business, Tutorials, News
- **SEO Metadata**: Titles, descriptions, featured images
- **Realistic Content**: Code examples, business insights, how-to guides

## Test Factories

### Base Factories (`test/factories/users.rb`)
```ruby
# Create a user with workspace
user = create(:user, :with_workspace)

# Create admin user
admin = create(:user, :admin)

# Create workspace with members
workspace = create(:workspace, :with_members)
```

### AI Factories (`test/factories/ai.rb`)
```ruby
# Create prompt template
template = create(:prompt_template, :code_review)

# Create completed LLM job with output
job = create(:llm_job, :completed)

# Create job with positive feedback
job = create(:llm_job, :completed) do |job|
  create(:llm_output, :with_positive_feedback, llm_job: job)
end
```

### Billing Factories (`test/factories/billing.rb`)
```ruby
# Create subscription plan
plan = create(:plan, :professional)

# Create active subscription
subscription = create(:subscription, user: user, plan: plan)

# Create usage records
create(:usage_record, :api_usage, subscription: subscription)
```

### CMS Factories (`test/factories/cms.rb`)
```ruby
# Create published blog post
post = create(:post, :published, :featured)

# Create technical post with code
post = create(:post, :technical)

# Create post with SEO optimization
post = create(:post, :with_seo)
```

## Idempotent Design

Seeds can be run multiple times safely:

```ruby
# Helper method ensures no duplicates
demo_user = find_or_create_by_with_attributes(
  User,
  { email: 'demo@example.com' },
  { password: 'password123', confirmed_at: Time.current }
)
```

## Module Integration

Seeds automatically detect installed modules:

```ruby
# Only runs if AI models are defined
if defined?(PromptTemplate) && defined?(LLMJob)
  load Rails.root.join('db', 'seeds', 'ai_seeds.rb')
end
```

## Development Workflow

1. **Generate app** with template
2. **Add modules** you need: `bin/synth add ai billing cms`
3. **Run migrations**: `rails db:migrate`
4. **Seed database**: `rails db:seed`
5. **Start developing** with realistic demo data

## Testing Workflow

```ruby
# In your tests, use factories for consistent data
describe 'AI Jobs' do
  let(:user) { create(:user) }
  let(:template) { create(:prompt_template, :code_review) }
  
  it 'processes LLM jobs' do
    job = create(:llm_job, user: user, prompt_template: template)
    # Test your job processing logic
  end
end
```

## Customization

### Adding Custom Seeds
Create module-specific seeds in `db/seeds/your_module_seeds.rb`:

```ruby
# db/seeds/your_module_seeds.rb
puts "   🔧 Creating your module data..."

your_data = find_or_create_by_with_attributes(
  YourModel,
  { identifier: 'unique_key' },
  { name: 'Demo Data', active: true }
)
```

### Extending Factories
Add traits to existing factories:

```ruby
# test/factories/your_custom_factories.rb
FactoryBot.modify do
  factory :user do
    trait :your_custom_trait do
      # Your custom user setup
    end
  end
end
```

## Best Practices

1. **Always use idempotent seeds** - check before creating
2. **Provide realistic demo data** - use real-world examples
3. **Include edge cases** - failed jobs, expired coupons, etc.
4. **Document your data** - explain what each seed creates
5. **Use factories in tests** - consistent, isolated test data

## Environment Variables

Some seeds may require configuration:

```bash
# .env file
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
OPENAI_API_KEY=sk-...
```

The seeds work without these keys but some functionality will be limited.

---

This comprehensive seed and factory system gives you a fully functional demo application immediately after generation, making development and testing much more efficient.