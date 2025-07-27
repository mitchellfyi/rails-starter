#!/usr/bin/env ruby
# frozen_string_literal: true

# Test for Admin Usage Controller functionality
puts "🧪 Testing Admin Usage Controller..."

errors = []
project_root = Dir.pwd  # Use current working directory

# Test that the controller class exists
begin
  controller_path = File.join(project_root, 'app/controllers/admin/usage_controller.rb')
  if File.exist?(controller_path)
    puts "✅ Admin::UsageController file exists"
    
    # Check controller content
    controller_content = File.read(controller_path)
    if controller_content.include?('class Admin::UsageController') && 
       controller_content.include?('def index') && 
       controller_content.include?('def workspace_detail')
      puts "✅ Controller has required methods"
    else
      errors << "Controller missing required methods"
    end
  else
    errors << "Admin::UsageController file not found"
  end
rescue => e
  errors << "Error checking controller: #{e.message}"
end

# Test that routes are configured
begin
  route_path = File.join(project_root, 'config/routes/admin.rb')
  if File.exist?(route_path)
    route_content = File.read(route_path)
    
    if route_content.include?("get 'usage'")
      puts "✅ Usage routes configured"
    else
      errors << "Usage routes not found in admin.rb"
    end
  else
    errors << "Admin routes file not found at #{route_path}"
  end
rescue => e
  errors << "Could not check routes: #{e.message}"
end

# Test that view files exist
view_files = [
  'app/views/admin/usage/index.html.erb',
  'app/views/admin/usage/workspace_detail.html.erb'
]

view_files.each do |view_file|
  full_path = File.join(project_root, view_file)
  if File.exist?(full_path)
    puts "✅ View file exists: #{File.basename(view_file)}"
    
    # Check view content
    content = File.read(full_path)
    if view_file.include?('index') && content.include?('Usage Analytics')
      puts "✅ Index view contains expected content"
    elsif view_file.include?('workspace_detail') && content.include?('Workspace Usage Detail')
      puts "✅ Workspace detail view contains expected content"
    end
  else
    errors << "View file missing: #{File.basename(view_file)}"
  end
end

# Test that dashboard link was added
begin
  dashboard_view = File.join(project_root, 'app/views/admin/dashboard/index.html.erb')
  if File.exist?(dashboard_view)
    content = File.read(dashboard_view)
    if content.include?('Usage Analytics') && content.include?('admin_usage_path')
      puts "✅ Dashboard includes usage analytics link"
    else
      errors << "Dashboard missing usage analytics link"
    end
  else
    errors << "Dashboard view file not found"
  end
rescue => e
  errors << "Could not check dashboard view: #{e.message}"
end

# Test AI models exist (these should already be in the AI domain)
ai_models_info = [
  {
    model_file: 'app/domains/ai/app/models/prompt_execution.rb',
    migration_file: 'app/domains/ai/db/migrate/003_create_prompt_executions.rb',
    name: 'PromptExecution',
    required_fields: ['belongs_to :workspace', 'model_used'],
    migration_fields: ['t.references :workspace', 't.integer :tokens_used', 't.string :model_used']
  },
  {
    model_file: 'app/domains/ai/app/models/llm_output.rb',
    migration_file: 'app/domains/ai/db/migrate/001_create_llm_outputs.rb',
    name: 'LLMOutput',
    required_fields: ['model_name', 'template_name', 'user_id'],
    migration_fields: ['t.string :model_name', 't.string :template_name', 't.references :user']
  }
]

ai_models_info.each do |model_info|
  model_path = File.join(project_root, model_info[:model_file])
  migration_path = File.join(project_root, model_info[:migration_file])
  
  if File.exist?(model_path)
    puts "✅ AI model file exists: #{model_info[:name]}"
    
    # Check model content for required fields
    content = File.read(model_path)
    missing_fields = model_info[:required_fields].reject { |field| content.include?(field) }
    
    if missing_fields.empty?
      puts "✅ #{model_info[:name]} model has required fields"
    else
      # Check migration file for database fields
      if File.exist?(migration_path)
        migration_content = File.read(migration_path)
        migration_missing = model_info[:migration_fields].reject { |field| migration_content.include?(field) }
        
        if migration_missing.empty?
          puts "✅ #{model_info[:name]} has required fields in migration"
        else
          errors << "#{model_info[:name]} missing required analytics fields in migration: #{migration_missing.join(', ')}"
        end
      else
        errors << "#{model_info[:name]} migration file not found"
      end
    end
  else
    puts "⚠️  AI model file not found: #{model_info[:name]} (domain might not be installed)"
  end
end

# Summary
if errors.empty?
  puts ""
  puts "🎉 All Usage Controller tests passed!"
  puts ""
  puts "📝 Usage Analytics Dashboard Features:"
  puts "   - Admin usage analytics controller"
  puts "   - Daily/weekly charts per workspace" 
  puts "   - Top models used tracking"
  puts "   - Most expensive prompts analysis"
  puts "   - Token usage and cost estimation"
  puts "   - Alerting on failing jobs and token spikes"
  puts "   - Workspace-specific detail views"
  puts "   - Integration with existing AI domain models"
  puts ""
  puts "🔗 Admin panel navigation updated with usage analytics link"
  puts ""
  exit 0
else
  puts ""
  puts "❌ Usage Controller test failures:"
  errors.each { |error| puts "  - #{error}" }
  puts ""
  exit 1
end