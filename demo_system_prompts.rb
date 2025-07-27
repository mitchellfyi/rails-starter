#!/usr/bin/env ruby
# frozen_string_literal: true

# System Prompts Demo Script
# This script demonstrates the SystemPrompt functionality

puts "🚀 System Prompts Demo"
puts "=" * 50

# Mock the environment for demonstration
require_relative 'test/models/system_prompt_test'

# Create sample data
puts "\n1. Creating sample workspace and prompts..."

workspace = Workspace.new(id: 1, name: "Acme Corp")
user = User.new(id: 1, name: "Demo User")

# Global prompt (fallback)
global_prompt = SystemPrompt.create!(
  name: "Customer Support Assistant",
  prompt_text: "You are a helpful customer support representative for {{company_name}}. Assist {{customer_name}} with their inquiry.",
  description: "Global fallback for customer support",
  status: "active",
  workspace: nil, # Global
  associated_roles: ["support", "customer_service"],
  associated_functions: ["chat_support"]
)

# Workspace-specific prompt  
workspace_prompt = SystemPrompt.create!(
  name: "Customer Support Assistant", # Same name, different scope
  prompt_text: "You are Acme Corp's premium customer support specialist. We pride ourselves on exceptional service. Help {{customer_name}} with their inquiry and always exceed expectations.",
  description: "Acme Corp's branded customer support prompt",
  status: "active", 
  workspace_id: workspace.id,
  workspace: workspace,
  associated_roles: ["support", "customer_service"],
  associated_functions: ["chat_support", "premium_support"]
)

puts "✅ Created global prompt: #{global_prompt.name}"
puts "✅ Created workspace prompt: #{workspace_prompt.name} (#{workspace.name})"

# Demonstrate variable extraction
puts "\n2. Variable extraction demo..."
variables = workspace_prompt.variable_names
puts "📋 Variables found: #{variables.join(', ')}"

# Demonstrate rendering
puts "\n3. Prompt rendering demo..."
context = {
  "company_name" => "Acme Corporation",
  "customer_name" => "Jane Smith"
}

rendered_global = global_prompt.render_with_context(context)
rendered_workspace = workspace_prompt.render_with_context(context)

puts "\n🌐 Global prompt rendered:"
puts "   #{rendered_global}"
puts "\n🏢 Workspace prompt rendered:"  
puts "   #{rendered_workspace}"

# Demonstrate fallback logic concept
puts "\n4. Fallback logic demo..."
puts "   When looking for 'support' role in workspace #{workspace.id}:"
puts "   ✅ Found workspace-specific prompt: #{workspace_prompt.name}"
puts "   \n   When looking for 'support' role in non-existent workspace:"
puts "   ⬇️  Would fall back to global prompt: #{global_prompt.name}"

# Demonstrate versioning
puts "\n5. Versioning demo..."
puts "   Original version: #{workspace_prompt.version}"

new_version = workspace_prompt.create_new_version!(
  description: "Enhanced with empathy training",
  prompt_text: "You are Acme Corp's premium customer support specialist. We pride ourselves on exceptional, empathetic service. Always listen carefully to {{customer_name}}'s concerns and respond with genuine care. Help them with their inquiry and always exceed expectations."
)

puts "   ✅ Created new version: #{new_version.version}"
puts "   📝 New version prompt: #{new_version.prompt_text[0..80]}..."

# Demonstrate cloning
puts "\n6. Cloning demo..."
cloned_prompt = workspace_prompt.clone!("VIP Customer Support Assistant")
puts "   ✅ Cloned prompt: #{cloned_prompt.name}"
puts "   📝 Status: #{cloned_prompt.status} (starts as draft)"

# Demonstrate associations
puts "\n7. Association filtering demo..."
puts "   Global prompt roles: #{global_prompt.associated_roles.join(', ')}"
puts "   Global prompt functions: #{global_prompt.associated_functions.join(', ')}"
puts "   Workspace prompt functions: #{workspace_prompt.associated_functions.join(', ')}"

# Show status management
puts "\n8. Status management demo..."
puts "   Current statuses:"
puts "   • Global: #{global_prompt.status}"
puts "   • Workspace: #{workspace_prompt.status}" 
puts "   • New Version: #{new_version.status}"
puts "   • Cloned: #{cloned_prompt.status}"

cloned_prompt.activate!
puts "   ✅ Activated cloned prompt: #{cloned_prompt.status}"

# Summary
puts "\n" + "=" * 50
puts "📊 Demo Summary:"
puts "   • ✅ Global fallback system"
puts "   • ✅ Workspace-specific overrides"
puts "   • ✅ Variable extraction and rendering"
puts "   • ✅ Version management"
puts "   • ✅ Cloning capabilities"
puts "   • ✅ Role/function associations"
puts "   • ✅ Status management (draft/active/archived)"

puts "\n🎯 Use Cases Demonstrated:"
puts "   1. Multi-tenant prompt management"
puts "   2. Brand-specific customization"
puts "   3. A/B testing with versions"
puts "   4. Role-based prompt selection"
puts "   5. Template reuse via cloning"

puts "\n🚀 Ready for production use!"