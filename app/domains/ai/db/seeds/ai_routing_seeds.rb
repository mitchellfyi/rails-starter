# frozen_string_literal: true

# Sample AI Routing Policies and Spending Limits
# This file contains seeds for demonstrating the AI routing and cost monitoring functionality

puts "Creating sample AI routing policies and spending limits..."

# Create sample users and workspaces if they don't exist
sample_user = User.find_or_create_by(email: 'admin@example.com') do |user|
  user.name = 'Admin User'
  user.password = 'password123'
end

sample_workspace = Workspace.find_or_create_by(name: 'Demo Workspace') do |workspace|
  workspace.description = 'Demonstration workspace for AI routing policies'
end

# Create AI Routing Policies
policies = [
  {
    name: 'Production Policy',
    primary_model: 'gpt-4',
    fallback_models: ['gpt-3.5-turbo'],
    cost_threshold_warning: 0.05,
    cost_threshold_block: 0.20,
    description: 'Production routing policy with GPT-4 primary and GPT-3.5 fallback',
    enabled: true
  },
  {
    name: 'Cost-Optimized Policy',
    primary_model: 'gpt-3.5-turbo',
    fallback_models: ['claude-3-haiku'],
    cost_threshold_warning: 0.02,
    cost_threshold_block: 0.10,
    description: 'Cost-optimized policy using cheaper models with tight cost controls',
    enabled: true
  },
  {
    name: 'High-Performance Policy',
    primary_model: 'gpt-4o',
    fallback_models: ['gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'],
    cost_threshold_warning: 0.10,
    cost_threshold_block: 0.50,
    description: 'High-performance policy with multiple fallbacks for critical workloads',
    enabled: false
  }
]

policies.each do |policy_attrs|
  ai_policy = sample_workspace.ai_routing_policies.find_or_create_by(
    name: policy_attrs[:name]
  ) do |policy|
    policy.primary_model = policy_attrs[:primary_model]
    policy.fallback_models = policy_attrs[:fallback_models]
    policy.cost_threshold_warning = policy_attrs[:cost_threshold_warning]
    policy.cost_threshold_block = policy_attrs[:cost_threshold_block]
    policy.description = policy_attrs[:description]
    policy.enabled = policy_attrs[:enabled]
    policy.created_by = sample_user
    policy.updated_by = sample_user
    
    # Set custom routing rules for demonstration
    policy.routing_rules = {
      'retry_attempts' => 3,
      'retry_delay' => 5,
      'timeout_seconds' => 30,
      'failure_conditions' => ['timeout', 'rate_limit', 'server_error']
    }
    
    # Set custom cost rules
    policy.cost_rules = {
      'calculate_before_request' => true,
      'track_actual_usage' => true,
      'notification_threshold_multiplier' => 0.8
    }
  end
  
  puts "✓ Created AI routing policy: #{ai_policy.name}"
end

# Create Workspace Spending Limit
spending_limit = sample_workspace.workspace_spending_limit || sample_workspace.build_workspace_spending_limit

spending_limit.update!(
  daily_limit: 25.00,
  weekly_limit: 150.00,
  monthly_limit: 500.00,
  current_daily_spend: 3.75,   # Some existing spend to show in UI
  current_weekly_spend: 18.50,
  current_monthly_spend: 75.25,
  last_reset_date: Date.current,
  enabled: true,
  block_when_exceeded: false,  # Just warn, don't block
  notification_emails: ['admin@example.com', 'billing@example.com'],
  created_by: sample_user,
  updated_by: sample_user
)

puts "✓ Created workspace spending limit with daily: $#{spending_limit.daily_limit}, weekly: $#{spending_limit.weekly_limit}, monthly: $#{spending_limit.monthly_limit}"

# Create some sample LLM outputs to show in the UI
sample_outputs = [
  {
    template_name: 'customer_support_response',
    model_name: 'gpt-4',
    format: 'text',
    status: 'completed',
    estimated_cost: 0.045,
    actual_cost: 0.042,
    input_tokens: 800,
    output_tokens: 300,
    cost_warning_triggered: false,
    routing_decision: {
      policy_used: true,
      policy_name: 'Production Policy',
      primary_model: 'gpt-4',
      final_model: 'gpt-4',
      total_attempts: 1
    }
  },
  {
    template_name: 'data_analysis',
    model_name: 'gpt-3.5-turbo',
    format: 'json',
    status: 'completed',
    estimated_cost: 0.078,
    actual_cost: 0.075,
    input_tokens: 1500,
    output_tokens: 800,
    cost_warning_triggered: true,
    routing_decision: {
      policy_used: true,
      policy_name: 'Production Policy',
      primary_model: 'gpt-4',
      final_model: 'gpt-3.5-turbo',
      total_attempts: 2,
      fallback_reason: 'Cost threshold exceeded'
    }
  },
  {
    template_name: 'content_generation',
    model_name: 'claude-3-haiku',
    format: 'markdown',
    status: 'completed',
    estimated_cost: 0.015,
    actual_cost: 0.013,
    input_tokens: 600,
    output_tokens: 400,
    cost_warning_triggered: false,
    routing_decision: {
      policy_used: true,
      policy_name: 'Cost-Optimized Policy',
      primary_model: 'gpt-3.5-turbo',
      final_model: 'claude-3-haiku',
      total_attempts: 2,
      fallback_reason: 'Primary model timeout'
    }
  }
]

sample_outputs.each_with_index do |output_attrs, index|
  llm_output = LLMOutput.find_or_create_by(
    job_id: "sample-job-#{index + 1}"
  ) do |output|
    output.template_name = output_attrs[:template_name]
    output.model_name = output_attrs[:model_name]
    output.format = output_attrs[:format]
    output.status = output_attrs[:status]
    output.estimated_cost = output_attrs[:estimated_cost]
    output.actual_cost = output_attrs[:actual_cost]
    output.input_tokens = output_attrs[:input_tokens]
    output.output_tokens = output_attrs[:output_tokens]
    output.cost_warning_triggered = output_attrs[:cost_warning_triggered]
    output.routing_decision = output_attrs[:routing_decision]
    output.workspace = sample_workspace
    output.user = sample_user
    output.context = { sample: true }
    output.prompt = "Sample prompt for #{output_attrs[:template_name]}"
    output.raw_response = "Sample response from #{output_attrs[:model_name]}"
    output.parsed_output = "Parsed: Sample response from #{output_attrs[:model_name]}"
    output.created_at = rand(7.days).seconds.ago
  end
  
  puts "✓ Created sample LLM output: #{llm_output.template_name} (#{llm_output.model_name})"
end

puts "\n🎉 Sample AI routing and cost monitoring data created successfully!"
puts "\nYou can now:"
puts "1. Visit the AI routing policies page to see the sample policies"
puts "2. View spending summaries and cost tracking"
puts "3. Test the routing preview functionality"
puts "4. Create new policies with different configurations"
puts "\nThe sample data includes:"
puts "- 3 different routing policies with various model configurations"
puts "- Workspace spending limits with sample usage data"
puts "- Sample LLM outputs showing routing decisions and cost tracking"