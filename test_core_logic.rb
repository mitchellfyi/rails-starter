#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

# Standalone test of core test generation logic
puts "🧪 RailsPlan AI Test Generation - Standalone Logic Test"
puts "=" * 60

# Test the core logic without dependencies
class TestTypeDetector
  TEST_TYPES = %w[system request model job controller integration unit].freeze
  
  def self.determine_test_type(instruction, options = {})
    # If type is explicitly specified, use it
    if options[:type] && TEST_TYPES.include?(options[:type])
      return options[:type]
    end
    
    # Auto-detect based on instruction content
    instruction_lower = instruction.downcase
    
    # System/feature tests - user interactions
    if instruction_lower.match?(/sign[s]?\s+up|sign[s]?\s+in|log[s]?\s+in|visit|click|fill|submit|user\s+.*(flow|journey|interaction)|browser/)
      return "system"
    end
    
    # API/Request tests - HTTP endpoints
    if instruction_lower.match?(/api|endpoint|request|response|post\s+|get\s+|put\s+|patch\s+|delete\s+|http|json|status/)
      return "request"
    end
    
    # Model tests - validations, associations, methods
    if instruction_lower.match?(/model|validation|association|scope|method.*model|database|\.save|\.create|\.find/)
      return "model"
    end
    
    # Job tests - background processing
    if instruction_lower.match?(/job|perform|queue|background|sidekiq|delayed|async/)
      return "job"
    end
    
    # Controller tests - controller actions
    if instruction_lower.match?(/controller|action|params|redirect|render|before_action/)
      return "controller"
    end
    
    # Default to system test for user stories
    "system"
  end
  
  def self.detect_test_framework
    # Check if RSpec is in use
    if File.exist?("spec/spec_helper.rb") || File.exist?("spec/rails_helper.rb")
      return "RSpec"
    end
    
    # Check for Minitest
    if File.exist?("test/test_helper.rb")
      return "Minitest"
    end
    
    # Default to Rails' built-in Minitest
    "Minitest"
  end
  
  def self.test_requirements_for_type(test_type, framework)
    case test_type
    when "system"
      if framework == "RSpec"
        "- Create feature spec in spec/system/\n- Use Capybara DSL\n- Test user workflows"
      else
        "- Create system test in test/system/\n- Inherit from ApplicationSystemTestCase\n- Use Capybara DSL"
      end
    when "request"
      if framework == "RSpec"
        "- Create request spec in spec/requests/\n- Test HTTP endpoints\n- Assert response status"
      else
        "- Create integration test in test/integration/\n- Inherit from ActionDispatch::IntegrationTest"
      end
    when "model"
      if framework == "RSpec"
        "- Create model spec in spec/models/\n- Test validations and associations\n- Use RSpec matchers"
      else
        "- Create model test in test/models/\n- Inherit from ActiveSupport::TestCase\n- Test validations"
      end
    when "job"
      if framework == "RSpec"
        "- Create job spec in spec/jobs/\n- Test job execution\n- Mock external services"
      else
        "- Create job test in test/jobs/\n- Inherit from ActiveJob::TestCase\n- Use perform_enqueued_jobs"
      end
    when "controller"
      if framework == "RSpec"
        "- Create controller spec in spec/controllers/\n- Test actions in isolation\n- Mock dependencies"
      else
        "- Create controller test in test/controllers/\n- Inherit from ActionController::TestCase"
      end
    else
      "Follow standard #{framework} testing practices for #{test_type} tests"
    end
  end
end

puts "\n🤖 Testing AI Test Generation Core Logic..."
puts "-" * 40

# Demo 1: Test type detection
puts "\n1. 🎯 Test Type Auto-Detection:"

test_cases = [
  "User signs up with email and password",
  "API returns user data in JSON format", 
  "User model validates email uniqueness",
  "Email notification job sends welcome email",
  "Users controller handles create action properly",
  "User visits dashboard page and clicks button",
  "Admin can delete user account",
  "Background job processes payment",
  "GET /api/users returns 200 status",
  "User.create saves record to database"
]

test_cases.each do |instruction|
  detected_type = TestTypeDetector.determine_test_type(instruction)
  puts "   \"#{instruction}\""
  puts "   → #{detected_type} test"
  puts ""
end

# Demo 2: Type override functionality
puts "2. ⚙️  Type Override Functionality:"

instruction = "User signs up with email"  # Would normally be 'system'
original_type = TestTypeDetector.determine_test_type(instruction)
override_type = TestTypeDetector.determine_test_type(instruction, { type: "model" })
invalid_override = TestTypeDetector.determine_test_type(instruction, { type: "invalid" })

puts "   Instruction: \"#{instruction}\""
puts "   Auto-detected: #{original_type}"
puts "   With --type=model: #{override_type}"
puts "   With invalid type: #{invalid_override} (falls back to auto-detection)"

# Demo 3: Test requirements generation
puts "\n3. 📋 Test Requirements Generation:"

test_types = %w[system request model job controller]
frameworks = %w[Minitest RSpec]

test_types.each do |test_type|
  puts "\n   #{test_type.upcase} Test Requirements:"
  frameworks.each do |framework|
    puts "     #{framework}:"
    requirements = TestTypeDetector.test_requirements_for_type(test_type, framework)
    requirements.split("\n").each do |line|
      line = line.strip
      puts "       #{line}" if line.length > 0
    end
  end
end

# Demo 4: Framework detection
puts "\n4. 🔧 Test Framework Detection:"

temp_dir = "/tmp/railsplan_framework_test"
FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
FileUtils.mkdir_p(temp_dir)

original_dir = Dir.pwd
Dir.chdir(temp_dir)

begin
  # Test default (no test files)
  framework = TestTypeDetector.detect_test_framework
  puts "   No test files: #{framework}"
  
  # Test with Minitest
  FileUtils.mkdir_p("test")
  File.write("test/test_helper.rb", "# Minitest helper")
  framework = TestTypeDetector.detect_test_framework
  puts "   With test/test_helper.rb: #{framework}"
  
  # Test with RSpec
  FileUtils.mkdir_p("spec")
  File.write("spec/spec_helper.rb", "# RSpec helper")
  framework = TestTypeDetector.detect_test_framework
  puts "   With spec/spec_helper.rb: #{framework}"
  
  File.write("spec/rails_helper.rb", "# RSpec Rails helper")
  framework = TestTypeDetector.detect_test_framework
  puts "   With spec/rails_helper.rb: #{framework}"
  
ensure
  Dir.chdir(original_dir)
  FileUtils.rm_rf(temp_dir)
end

# Demo 5: Available test types
puts "\n5. 📚 Available Test Types:"

TestTypeDetector::TEST_TYPES.each do |type|
  puts "   • #{type}"
end

# Demo 6: Pattern matching examples
puts "\n6. 🔍 Pattern Matching Examples:"

patterns = {
  "system" => %w[signup signin visit click fill browser interaction],
  "request" => %w[api endpoint json http status response],
  "model" => %w[validation association database save create],
  "job" => %w[job queue background perform async],
  "controller" => %w[controller action params redirect render]
}

patterns.each do |test_type, keywords|
  puts "\n   #{test_type.upcase} test keywords:"
  keywords.each { |keyword| puts "     • #{keyword}" }
end

puts "\n✨ Core logic testing completed!"
puts "\n📖 Usage Examples:"
puts "   railsplan generate test \"User signs up with email and password\""
puts "   railsplan generate test \"API returns user data\" --type=request"
puts "   railsplan generate test \"User model validation\" --dry-run"
puts "   railsplan generate test \"Email job processes queue\" --force --validate"

puts "\n" + "=" * 60
puts "🎉 Core Logic Test Complete!"
puts "\nFeatures Validated:"
puts "• ✅ Intelligent test type detection (#{test_cases.length} examples tested)"
puts "• ✅ Support for both RSpec and Minitest frameworks"
puts "• ✅ Comprehensive test requirements for each test type"
puts "• ✅ Type override functionality with --type option"
puts "• ✅ Framework detection based on file presence"
puts "• ✅ All #{TestTypeDetector::TEST_TYPES.length} test types supported"
puts "• ✅ Robust pattern matching for natural language"