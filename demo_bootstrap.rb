#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script to showcase the Bootstrap CLI functionality
# This script simulates the interactive bootstrap wizard

require 'securerandom'

puts "🚀 Rails SaaS Starter - Bootstrap CLI Demo"
puts "=" * 50
puts ""

puts "This demo showcases the new interactive Bootstrap CLI wizard."
puts "The wizard would normally prompt for user input, but this demo"
puts "shows what the generated output would look like."
puts ""

# Simulate user configuration
demo_config = {
  app_name: "MyAwesome SaaS",
  app_domain: "myawesome.com",
  environment: "production",
  team_name: "Awesome Team",
  owner_email: "admin@myawesome.com",
  admin_password: "SecurePassword123!",
  modules: ["ai", "billing", "cms"],
  llm_provider: "openai",
  credentials: {
    stripe: {
      publishable_key: "pk_live_...",
      secret_key: "sk_live_...",
      webhook_secret: "whsec_..."
    },
    openai: {
      api_key: "sk-...",
      organization_id: "org-..."
    },
    github: {
      client_id: "github_client_123",
      client_secret: "github_secret_456",
      token: "ghp_token_789"
    },
    smtp: {
      host: "smtp.myawesome.com",
      port: "587",
      username: "noreply@myawesome.com",
      password: "smtp_pass_123"
    }
  }
}

puts "📋 Configuration Summary:"
puts "=" * 25
puts "App Name: #{demo_config[:app_name]}"
puts "Domain: #{demo_config[:app_domain]}"
puts "Environment: #{demo_config[:environment]}"
puts "Team: #{demo_config[:team_name]}"
puts "Owner: #{demo_config[:owner_email]}"
puts "Admin Password: #{demo_config[:admin_password]}"
puts "Selected Modules: #{demo_config[:modules].join(', ')}"
puts "LLM Provider: #{demo_config[:llm_provider]}"
puts ""

puts "📝 Generated .env content (sample):"
puts "-" * 35

env_sample = <<~ENV
# Basic Rails SaaS Configuration
RAILS_ENV=#{demo_config[:environment]}
SECRET_KEY_BASE=#{SecureRandom.hex(32)}

# Application Configuration
APP_NAME=#{demo_config[:app_name]}
APP_HOST=#{demo_config[:app_domain]}

# Database Configuration
DATABASE_URL=postgresql://user:pass@localhost:5432/myawesome_production

# Admin Configuration  
ADMIN_EMAIL=#{demo_config[:owner_email]}
ADMIN_PASSWORD=#{demo_config[:admin_password]}
TEAM_NAME=#{demo_config[:team_name]}

# Stripe Configuration (for billing module)
STRIPE_PUBLISHABLE_KEY=#{demo_config[:credentials][:stripe][:publishable_key]}
STRIPE_SECRET_KEY=#{demo_config[:credentials][:stripe][:secret_key]}
STRIPE_WEBHOOK_SECRET=#{demo_config[:credentials][:stripe][:webhook_secret]}

# OpenAI Configuration (for AI module)
OPENAI_API_KEY=#{demo_config[:credentials][:openai][:api_key]}
OPENAI_ORGANIZATION_ID=#{demo_config[:credentials][:openai][:organization_id]}

# GitHub Configuration
GITHUB_CLIENT_ID=#{demo_config[:credentials][:github][:client_id]}
GITHUB_CLIENT_SECRET=#{demo_config[:credentials][:github][:client_secret]}
GITHUB_TOKEN=#{demo_config[:credentials][:github][:token]}

# SMTP Configuration
SMTP_HOST=#{demo_config[:credentials][:smtp][:host]}
SMTP_PORT=#{demo_config[:credentials][:smtp][:port]}
SMTP_USERNAME=#{demo_config[:credentials][:smtp][:username]}
SMTP_PASSWORD=#{demo_config[:credentials][:smtp][:password]}
ENV

puts env_sample
puts ""

puts "🌱 Generated db/seeds.rb content:"
puts "-" * 32

seeds_sample = <<~SEEDS
# Bootstrap generated seeds
# Created by Rails SaaS Starter Bootstrap Wizard

# Create admin user
admin_user = User.find_or_create_by(email: '#{demo_config[:owner_email]}') do |user|
  user.password = '#{demo_config[:admin_password]}'
  user.password_confirmation = '#{demo_config[:admin_password]}'
  user.confirmed_at = Time.current
  user.admin = true
end

puts "Created admin user: \#{admin_user.email}" if admin_user.persisted?

# Create default team
if defined?(Team)
  team = Team.find_or_create_by(name: '#{demo_config[:team_name]}') do |t|
    t.owner = admin_user
  end
  
  puts "Created team: \#{team.name}" if team.persisted?
end

puts "Bootstrap seeds completed!"
SEEDS

puts seeds_sample
puts ""

puts "📦 Modules that would be installed:"
puts "-" * 32
demo_config[:modules].each do |mod|
  puts "  ✅ #{mod}"
  case mod
  when "ai"
    puts "     - AI-powered features with #{demo_config[:llm_provider]} integration"
    puts "     - Credential management and environment scanning"
  when "billing"
    puts "     - Stripe integration for subscriptions and payments"
    puts "     - Usage tracking and billing management"
  when "cms"
    puts "     - Content management system"
    puts "     - GitHub integration for content workflows"
  end
end

puts ""
puts "🎉 Bootstrap Complete!"
puts ""
puts "📋 Next steps after running bootstrap:"
puts "   1. Review and customize the generated .env file"
puts "   2. Run: rails db:create db:migrate db:seed" 
puts "   3. Start your application: rails server"
puts "   4. Access admin panel: http://#{demo_config[:app_domain]}/admin"
puts "      Email: #{demo_config[:owner_email]}"
puts "      Password: #{demo_config[:admin_password]}"
puts ""
puts "🚀 Your Rails SaaS application is ready to launch!"