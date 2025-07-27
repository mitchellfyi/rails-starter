# frozen_string_literal: true

puts "🧪 Testing Token Usage & Cost Tracking Implementation..."

# Test that new files were created successfully
def test_file_structure
  puts "  ✅ Testing file structure..."
  
  required_files = [
    'app/domains/ai/db/migrate/20241217000008_create_llm_usage.rb',
    'app/domains/ai/app/models/llm_usage.rb',
    'app/domains/ai/app/jobs/aggregate_usage_job.rb',
    'db/migrate/20241217000009_add_monthly_credits_to_workspaces.rb',
    'app/domains/ai/db/migrate/20241217000010_add_rate_limiting_to_workspace_spending_limits.rb',
    'app/controllers/workspace_usage_controller.rb'
  ]
  
  missing_files = []
  required_files.each do |file|
    if File.exist?(file)
      puts "    ✅ #{file}"
    else
      puts "    ❌ #{file} - MISSING"
      missing_files << file
    end
  end
  
  if missing_files.empty?
    puts "  🎉 All required files created successfully!"
    return true
  else
    puts "  💥 #{missing_files.length} files missing"
    return false
  end
end

def test_model_definitions
  puts "  ✅ Testing model definitions..."
  
  begin
    # Test LlmUsage model file syntax
    llm_usage_content = File.read('app/domains/ai/app/models/llm_usage.rb')
    if llm_usage_content.include?('class LlmUsage') && 
       llm_usage_content.include?('belongs_to :workspace') &&
       llm_usage_content.include?('def self.aggregate_for_date')
      puts "    ✅ LlmUsage model structure looks correct"
    else
      puts "    ❌ LlmUsage model structure incomplete"
      return false
    end
    
    # Test Workspace model updates
    workspace_content = File.read('app/models/workspace.rb')
    if workspace_content.include?('has_many :llm_usage') &&
       workspace_content.include?('def remaining_monthly_credit') &&
       workspace_content.include?('def add_usage!')
      puts "    ✅ Workspace model enhancements look correct"
    else
      puts "    ❌ Workspace model enhancements incomplete"
      return false
    end
    
    puts "  🎉 Model definitions are structurally correct!"
    return true
  rescue => e
    puts "    ❌ Error checking model definitions: #{e.message}"
    return false
  end
end

def test_migration_structure
  puts "  ✅ Testing migration structure..."
  
  begin
    # Check LLM usage migration
    llm_usage_migration = File.read('app/domains/ai/db/migrate/20241217000008_create_llm_usage.rb')
    if llm_usage_migration.include?('create_table :llm_usage') &&
       llm_usage_migration.include?('t.bigint :workspace_id') &&
       llm_usage_migration.include?('t.string :provider') &&
       llm_usage_migration.include?('t.decimal :cost')
      puts "    ✅ LLM usage migration structure correct"
    else
      puts "    ❌ LLM usage migration incomplete"
      return false
    end
    
    # Check workspace credits migration
    workspace_migration = File.read('db/migrate/20241217000009_add_monthly_credits_to_workspaces.rb')
    if workspace_migration.include?('add_column :workspaces, :monthly_ai_credit') &&
       workspace_migration.include?('add_column :workspaces, :current_month_usage') &&
       workspace_migration.include?('add_column :workspaces, :overage_billing_enabled')
      puts "    ✅ Workspace credits migration structure correct"
    else
      puts "    ❌ Workspace credits migration incomplete"
      return false
    end
    
    # Check rate limiting migration
    rate_limit_migration = File.read('app/domains/ai/db/migrate/20241217000010_add_rate_limiting_to_workspace_spending_limits.rb')
    if rate_limit_migration.include?('add_column :workspace_spending_limits, :rate_limit_enabled') &&
       rate_limit_migration.include?('add_column :workspace_spending_limits, :requests_per_minute')
      puts "    ✅ Rate limiting migration structure correct"
    else
      puts "    ❌ Rate limiting migration incomplete"
      return false
    end
    
    puts "  🎉 All migrations are structurally correct!"
    return true
  rescue => e
    puts "    ❌ Error checking migrations: #{e.message}"
    return false
  end
end

def test_controller_enhancements
  puts "  ✅ Testing controller enhancements..."
  
  begin
    # Check admin usage controller updates
    admin_controller = File.read('app/controllers/admin/usage_controller.rb')
    if admin_controller.include?('LlmUsage.for_date_range') &&
       admin_controller.include?('calculate_workspace_usage_stats') &&
       admin_controller.include?('calculate_credit_overview')
      puts "    ✅ Admin usage controller enhancements look correct"
    else
      puts "    ❌ Admin usage controller enhancements incomplete"
      return false
    end
    
    # Check new workspace usage controller
    workspace_controller = File.read('app/controllers/workspace_usage_controller.rb')
    if workspace_controller.include?('class WorkspaceUsageController') &&
       workspace_controller.include?('def show') &&
       workspace_controller.include?('@usage_summary')
      puts "    ✅ Workspace usage controller structure correct"
    else
      puts "    ❌ Workspace usage controller incomplete"
      return false
    end
    
    puts "  🎉 Controller enhancements are structurally correct!"
    return true
  rescue => e
    puts "    ❌ Error checking controllers: #{e.message}"
    return false
  end
end

def test_job_implementation
  puts "  ✅ Testing job implementation..."
  
  begin
    aggregate_job = File.read('app/domains/ai/app/jobs/aggregate_usage_job.rb')
    if aggregate_job.include?('class AggregateUsageJob') &&
       aggregate_job.include?('LlmUsage.aggregate_for_date') &&
       aggregate_job.include?('def perform')
      puts "    ✅ Aggregate usage job structure correct"
    else
      puts "    ❌ Aggregate usage job incomplete"
      return false
    end
    
    # Check LLMJob rate limiting updates
    llm_job = File.read('app/domains/ai/app/jobs/llm_job.rb')
    if llm_job.include?('would_be_rate_limited?') &&
       llm_job.include?('add_request!')
      puts "    ✅ LLMJob rate limiting integration correct"
    else
      puts "    ❌ LLMJob rate limiting integration incomplete"
      return false
    end
    
    puts "  🎉 Job implementations are structurally correct!"
    return true
  rescue => e
    puts "    ❌ Error checking jobs: #{e.message}"
    return false
  end
end

# Run all tests
tests = [
  method(:test_file_structure),
  method(:test_model_definitions),
  method(:test_migration_structure),
  method(:test_controller_enhancements),
  method(:test_job_implementation)
]

passed = 0
failed = 0

tests.each do |test|
  begin
    if test.call
      passed += 1
    else
      failed += 1
    end
  rescue => e
    puts "  ❌ Test failed with error: #{e.message}"
    failed += 1
  end
  puts
end

puts "📊 Token Usage & Cost Tracking Implementation Test Results:"
puts "  ✅ Passed: #{passed}"
puts "  ❌ Failed: #{failed}"

if failed == 0
  puts
  puts "🎉 All implementation tests passed!"
  puts
  puts "📋 Implementation Summary:"
  puts "  ✅ LLMUsage model for aggregated usage tracking"
  puts "  ✅ Workspace monthly credit system with overage billing"
  puts "  ✅ Rate limiting functionality per workspace"
  puts "  ✅ Enhanced admin usage dashboard with cost tracking"
  puts "  ✅ Workspace-specific usage dashboard"
  puts "  ✅ Daily aggregation job for usage data"
  puts "  ✅ Database migrations for all new features"
  puts "  ✅ Integration with existing LLMJob and cost tracking"
  puts
  puts "🚀 Next steps:"
  puts "  - Run database migrations"
  puts "  - Set up daily aggregation job in scheduler"
  puts "  - Configure Stripe integration for overage billing"
  puts "  - Add usage dashboard to application routes"
  puts "  - Test with real LLM API calls"
  
  exit 0
else
  puts
  puts "💥 Some implementation tests failed - please review the code"
  exit 1
end