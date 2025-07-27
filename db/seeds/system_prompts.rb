# frozen_string_literal: true

# SystemPrompt Seeds
# This file provides sample system prompts for different use cases

puts "🌱 Seeding SystemPrompts..."

# Sample workspace (use existing or create one)
sample_workspace = Workspace.first || Workspace.create!(
  name: "Demo Workspace",
  slug: "demo-workspace",
  description: "Sample workspace for demonstration purposes"
)

# Global System Prompts (available to all workspaces as fallback)
global_prompts = [
  {
    name: "Generic Assistant",
    description: "A helpful, harmless, and honest AI assistant",
    prompt_text: "You are a helpful, harmless, and honest AI assistant. Please provide accurate and helpful responses to the user's questions.",
    status: "active",
    associated_roles: ["assistant", "general"],
    associated_functions: ["chat", "support"]
  },
  {
    name: "Code Review Assistant",
    description: "AI assistant specialized in code review and programming help",
    prompt_text: "You are an expert software engineer AI assistant. Help users with code review, debugging, and programming best practices. Always explain your reasoning and provide examples when helpful.",
    status: "active",
    associated_roles: ["developer", "engineer"],
    associated_functions: ["code_review", "debugging", "programming"],
    associated_agents: ["code_bot"]
  },
  {
    name: "Customer Support Bot",
    description: "Friendly customer support assistant",
    prompt_text: "You are a friendly and professional customer support representative for {{company_name}}. Help customers with their questions and concerns. If you cannot resolve an issue, politely escalate to a human agent.",
    status: "active",
    associated_roles: ["support", "customer_service"],
    associated_functions: ["support_chat", "ticket_handling"],
    associated_agents: ["support_bot"]
  }
]

global_prompts.each do |prompt_data|
  existing = SystemPrompt.find_by(name: prompt_data[:name], workspace: nil)
  if existing
    puts "  ⚠️  Global prompt '#{prompt_data[:name]}' already exists, skipping..."
  else
    SystemPrompt.create!(prompt_data.merge(workspace: nil))
    puts "  ✅ Created global prompt: #{prompt_data[:name]}"
  end
end

# Workspace-specific System Prompts
workspace_prompts = [
  {
    name: "Sales Assistant",
    description: "AI assistant specialized for sales interactions in this workspace",
    prompt_text: "You are a sales assistant for {{company_name}}. Help prospects understand our products and services. Be enthusiastic but not pushy. Focus on understanding customer needs: {{customer_needs}}. Always follow up with relevant questions.",
    status: "active",
    workspace: sample_workspace,
    associated_roles: ["sales", "business_development"],
    associated_functions: ["lead_qualification", "product_demo"],
    associated_agents: ["sales_bot"]
  },
  {
    name: "Technical Documentation Helper",
    description: "Assists with creating and maintaining technical documentation",
    prompt_text: "You are a technical writing assistant for {{company_name}}. Help create clear, accurate, and user-friendly documentation. Follow our style guide and ensure all documentation is accessible to users with varying technical backgrounds.",
    status: "active",
    workspace: sample_workspace,
    associated_roles: ["technical_writer", "developer"],
    associated_functions: ["documentation", "knowledge_base"],
    associated_agents: ["docs_bot"]
  },
  {
    name: "Project Management Assistant",
    description: "Helps with project planning and management tasks",
    prompt_text: "You are a project management assistant. Help with task planning, timeline estimation, and project coordination. Consider team capacity, dependencies, and risk factors when making recommendations for project: {{project_name}}.",
    status: "draft",
    workspace: sample_workspace,
    associated_roles: ["project_manager", "team_lead"],
    associated_functions: ["project_planning", "task_management"],
    associated_agents: ["pm_bot"]
  }
]

workspace_prompts.each do |prompt_data|
  existing = SystemPrompt.find_by(name: prompt_data[:name], workspace: prompt_data[:workspace])
  if existing
    puts "  ⚠️  Workspace prompt '#{prompt_data[:name]}' already exists in #{prompt_data[:workspace].name}, skipping..."
  else
    SystemPrompt.create!(prompt_data)
    puts "  ✅ Created workspace prompt: #{prompt_data[:name]} (#{prompt_data[:workspace].name})"
  end
end

# Create some version examples
puts "\n🔄 Creating version examples..."

# Create a new version of the Customer Support Bot
support_bot = SystemPrompt.find_by(name: "Customer Support Bot", workspace: nil)
if support_bot && support_bot.version_history.count == 1
  new_version = support_bot.create_new_version!(
    description: "Enhanced customer support with escalation handling",
    prompt_text: "You are a friendly and professional customer support representative for {{company_name}}. Help customers with their questions and concerns. 

Before escalating to a human agent, try these steps:
1. Ask clarifying questions to better understand the issue
2. Check our knowledge base for solutions
3. Provide step-by-step troubleshooting if applicable

If you still cannot resolve the issue, politely escalate to a human agent and provide a summary of what you've already tried.",
    associated_functions: support_bot.associated_functions + ["escalation_handling", "troubleshooting"]
  )
  puts "  ✅ Created version #{new_version.version} of Customer Support Bot"
else
  puts "  ⚠️  Customer Support Bot versions already exist, skipping..."
end

# Activate the Sales Assistant to show active status
sales_assistant = SystemPrompt.find_by(name: "Sales Assistant", workspace: sample_workspace)
if sales_assistant && sales_assistant.status != 'active'
  sales_assistant.activate!
  puts "  ✅ Activated Sales Assistant"
end

puts "\n✨ SystemPrompt seeding completed!"
puts "\n📊 Summary:"
puts "  • #{SystemPrompt.global.count} global system prompts"
puts "  • #{SystemPrompt.for_workspace(sample_workspace).count} workspace-specific prompts"
puts "  • #{SystemPrompt.active.count} active prompts"
puts "  • #{SystemPrompt.where(status: 'draft').count} draft prompts"
puts "\n🎯 Try these features:"
puts "  • View global prompts at /system_prompts"
puts "  • View workspace prompts at /system_prompts?workspace_id=#{sample_workspace.id}"
puts "  • Test the fallback system by looking for prompts by role/function"
puts "  • Try cloning and creating new versions of existing prompts"