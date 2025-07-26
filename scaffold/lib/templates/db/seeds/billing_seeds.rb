# frozen_string_literal: true

# Billing Module Seeds
# Creates Stripe dummy products, plans, and coupons for testing different billing scenarios

puts "   💰 Creating Stripe products and plans..."

# Free Trial Plan
free_plan = find_or_create_by_with_attributes(
  Plan,
  { stripe_id: 'plan_free_trial' },
  {
    name: 'Free Trial',
    description: '14-day free trial with full access to all features',
    amount_cents: 0,
    currency: 'usd',
    interval: 'month',
    interval_count: 1,
    trial_period_days: 14,
    active: true,
    features: [
      'Up to 100 AI requests per month',
      'Basic prompt templates',
      'Email support',
      '1 workspace'
    ]
  }
)

# Starter Subscription Plan
starter_plan = find_or_create_by_with_attributes(
  Plan,
  { stripe_id: 'plan_starter_monthly' },
  {
    name: 'Starter',
    description: 'Perfect for individuals and small teams getting started',
    amount_cents: 2900, # $29.00
    currency: 'usd',
    interval: 'month',
    interval_count: 1,
    trial_period_days: 14,
    active: true,
    features: [
      'Up to 1,000 AI requests per month',
      'All prompt templates',
      'Priority email support',
      '3 workspaces',
      'Basic analytics'
    ]
  }
)

# Professional Subscription Plan
pro_plan = find_or_create_by_with_attributes(
  Plan,
  { stripe_id: 'plan_pro_monthly' },
  {
    name: 'Professional',
    description: 'Advanced features for growing teams and businesses',
    amount_cents: 9900, # $99.00
    currency: 'usd',
    interval: 'month',
    interval_count: 1,
    trial_period_days: 14,
    active: true,
    features: [
      'Up to 10,000 AI requests per month',
      'Custom prompt templates',
      'Live chat support',
      'Unlimited workspaces',
      'Advanced analytics',
      'API access',
      'White-label options'
    ]
  }
)

# Annual Professional Plan (with discount)
pro_annual_plan = find_or_create_by_with_attributes(
  Plan,
  { stripe_id: 'plan_pro_annual' },
  {
    name: 'Professional (Annual)',
    description: 'Professional plan billed annually with 20% savings',
    amount_cents: 95040, # $950.40 (20% off $99 * 12)
    currency: 'usd',
    interval: 'year',
    interval_count: 1,
    trial_period_days: 14,
    active: true,
    features: [
      'Up to 10,000 AI requests per month',
      'Custom prompt templates',
      'Live chat support',
      'Unlimited workspaces',
      'Advanced analytics',
      'API access',
      'White-label options',
      '20% annual savings'
    ]
  }
)

# Enterprise Plan
enterprise_plan = find_or_create_by_with_attributes(
  Plan,
  { stripe_id: 'plan_enterprise' },
  {
    name: 'Enterprise',
    description: 'Custom solutions for large organizations',
    amount_cents: 49900, # $499.00
    currency: 'usd',
    interval: 'month',
    interval_count: 1,
    trial_period_days: 30,
    active: true,
    features: [
      'Unlimited AI requests',
      'Custom integrations',
      'Dedicated support manager',
      'Unlimited workspaces',
      'Custom analytics dashboards',
      'Full API access',
      'Custom white-label branding',
      'SSO integration',
      'Advanced security features'
    ]
  }
)

# Create Products for One-time Purchases
puts "   🛒 Creating one-time purchase products..."

# AI Credits Product
ai_credits = find_or_create_by_with_attributes(
  Product,
  { stripe_id: 'prod_ai_credits_1000' },
  {
    name: 'AI Credits Pack - 1,000 requests',
    description: 'Additional AI request credits for your account',
    amount_cents: 1900, # $19.00
    currency: 'usd',
    product_type: 'one_time',
    metadata: { credits: 1000 }
  }
)

# Custom Template Design
template_design = find_or_create_by_with_attributes(
  Product,
  { stripe_id: 'prod_template_design' },
  {
    name: 'Custom Prompt Template Design',
    description: 'Professional design of custom prompt templates by our experts',
    amount_cents: 29900, # $299.00
    currency: 'usd',
    product_type: 'one_time',
    metadata: { deliverable: 'custom_templates', turnaround_days: 7 }
  }
)

# Setup & Training Service
setup_service = find_or_create_by_with_attributes(
  Product,
  { stripe_id: 'prod_setup_training' },
  {
    name: 'Setup & Training Service',
    description: '2-hour onboarding session with AI workflow optimization',
    amount_cents: 49900, # $499.00
    currency: 'usd',
    product_type: 'one_time',
    metadata: { service_hours: 2, includes_recording: true }
  }
)

# Metered Billing Product (for usage-based pricing)
puts "   📊 Creating metered billing products..."

api_usage = find_or_create_by_with_attributes(
  Product,
  { stripe_id: 'prod_api_usage' },
  {
    name: 'API Usage',
    description: 'Pay-per-use API requests beyond plan limits',
    amount_cents: 5, # $0.05 per request
    currency: 'usd',
    product_type: 'metered',
    billing_scheme: 'per_unit',
    metadata: { unit: 'api_request' }
  }
)

# Premium AI Model Usage
premium_model_usage = find_or_create_by_with_attributes(
  Product,
  { stripe_id: 'prod_premium_ai_usage' },
  {
    name: 'Premium AI Model Usage',
    description: 'Usage of GPT-4 and other premium models',
    amount_cents: 10, # $0.10 per request
    currency: 'usd',
    product_type: 'metered',
    billing_scheme: 'per_unit',
    metadata: { unit: 'premium_request', models: ['gpt-4', 'claude-3'] }
  }
)

# Create Coupons for various scenarios
puts "   🎫 Creating discount coupons..."

# Welcome discount
welcome_coupon = find_or_create_by_with_attributes(
  Coupon,
  { stripe_id: 'coup_welcome50' },
  {
    name: 'WELCOME50',
    description: '50% off first month for new customers',
    percent_off: 50,
    duration: 'once',
    max_redemptions: 1000,
    active: true,
    metadata: { campaign: 'welcome', target: 'new_customers' }
  }
)

# Loyalty discount
loyalty_coupon = find_or_create_by_with_attributes(
  Coupon,
  { stripe_id: 'coup_loyal25' },
  {
    name: 'LOYAL25',
    description: '25% off for 3 months for existing customers',
    percent_off: 25,
    duration: 'repeating',
    duration_in_months: 3,
    max_redemptions: 500,
    active: true,
    metadata: { campaign: 'loyalty', target: 'existing_customers' }
  }
)

# Student discount
student_coupon = find_or_create_by_with_attributes(
  Coupon,
  { stripe_id: 'coup_student_fixed' },
  {
    name: 'STUDENT',
    description: '$10 off monthly plans for students',
    amount_off_cents: 1000, # $10.00
    currency: 'usd',
    duration: 'forever',
    active: true,
    metadata: { campaign: 'education', requires_verification: true }
  }
)

# Black Friday special
black_friday_coupon = find_or_create_by_with_attributes(
  Coupon,
  { stripe_id: 'coup_blackfriday2024' },
  {
    name: 'BLACKFRIDAY2024',
    description: '40% off annual plans - limited time!',
    percent_off: 40,
    duration: 'once',
    redeem_by: Date.parse('2024-12-01'),
    max_redemptions: 200,
    active: true,
    metadata: { campaign: 'seasonal', event: 'black_friday_2024' }
  }
)

# Create sample subscription for demo user
puts "   📋 Creating demo subscription..."

demo_subscription = find_or_create_by_with_attributes(
  Subscription,
  { user: demo_user },
  {
    plan: starter_plan,
    stripe_id: 'sub_demo_user_starter',
    status: 'active',
    current_period_start: 1.week.ago,
    current_period_end: 3.weeks.from_now,
    trial_start: 2.weeks.ago,
    trial_end: 1.week.ago,
    cancel_at_period_end: false
  }
)

# Create some usage records for metered billing demo
if defined?(UsageRecord)
  puts "   📈 Creating usage records for metered billing demo..."
  
  # API usage over the past week
  7.times do |i|
    find_or_create_by_with_attributes(
      UsageRecord,
      {
        subscription: demo_subscription,
        product: api_usage,
        timestamp: i.days.ago.beginning_of_day
      },
      {
        quantity: rand(50..200),
        recorded_at: i.days.ago.end_of_day
      }
    )
  end
  
  # Premium model usage
  find_or_create_by_with_attributes(
    UsageRecord,
    {
      subscription: demo_subscription,
      product: premium_model_usage,
      timestamp: 1.day.ago.beginning_of_day
    },
    {
      quantity: rand(5..25),
      recorded_at: 1.day.ago.end_of_day
    }
  )
end

puts "   ✅ Billing module seeding complete"