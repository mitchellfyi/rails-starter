#!/usr/bin/env ruby
# frozen_string_literal: true

# Manual integration test for onboarding module
# This can be run in a generated Rails app to verify onboarding functionality

puts "🧪 Testing Onboarding Module Integration..."

# Test 1: Check if onboarding routes are available
puts "Checking onboarding routes..."
if File.exist?('config/routes.rb')
  routes_content = File.read('config/routes.rb')
  if routes_content.include?('onboarding')
    puts "✅ Onboarding routes found in config/routes.rb"
  else
    puts "❌ Onboarding routes not found in config/routes.rb"
  end
else
  puts "❌ config/routes.rb not found - not in a Rails app?"
end

# Test 2: Check if onboarding models exist
puts "Checking onboarding models..."
onboarding_model_path = 'app/domains/onboarding/app/models/onboarding_progress.rb'
if File.exist?(onboarding_model_path)
  puts "✅ OnboardingProgress model found"
else
  puts "❌ OnboardingProgress model not found at #{onboarding_model_path}"
end

onboardable_concern_path = 'app/domains/onboarding/app/models/concerns/onboardable.rb'
if File.exist?(onboardable_concern_path)
  puts "✅ Onboardable concern found"
else
  puts "❌ Onboardable concern not found at #{onboardable_concern_path}"
end

# Test 3: Check if onboarding controller exists
puts "Checking onboarding controller..."
controller_path = 'app/domains/onboarding/app/controllers/onboarding_controller.rb'
if File.exist?(controller_path)
  puts "✅ OnboardingController found"
else
  puts "❌ OnboardingController not found at #{controller_path}"
end

# Test 4: Check if onboarding views exist
puts "Checking onboarding views..."
views_path = 'app/domains/onboarding/app/views/onboarding'
if Dir.exist?(views_path)
  view_files = Dir.glob("#{views_path}/**/*.html.erb")
  if view_files.length > 0
    puts "✅ Found #{view_files.length} onboarding view files"
  else
    puts "❌ No onboarding view files found"
  end
else
  puts "❌ Onboarding views directory not found at #{views_path}"
end

# Test 5: Check if onboarding migration exists
puts "Checking onboarding migration..."
migration_files = Dir.glob('db/migrate/*onboarding*')
if migration_files.any?
  puts "✅ Found onboarding migration: #{migration_files.first}"
else
  puts "❌ No onboarding migration found"
end

# Test 6: Check if User model includes Onboardable
puts "Checking User model integration..."
user_model_path = 'app/models/user.rb'
if File.exist?(user_model_path)
  user_content = File.read(user_model_path)
  if user_content.include?('Onboardable')
    puts "✅ User model includes Onboardable concern"
  else
    puts "❌ User model does not include Onboardable concern"
  end
else
  puts "❌ User model not found"
end

# Test 7: Test basic Ruby syntax of onboarding files
puts "Testing syntax of onboarding files..."
syntax_errors = []

onboarding_files = Dir.glob('app/domains/onboarding/**/*.rb')
onboarding_files.each do |file|
  result = `ruby -c "#{file}" 2>&1`
  unless result.include?('Syntax OK')
    syntax_errors << "#{file}: #{result}"
  end
end

if syntax_errors.empty?
  puts "✅ All onboarding Ruby files have valid syntax"
else
  puts "❌ Syntax errors found:"
  syntax_errors.each { |error| puts "   #{error}" }
end

puts ""
puts "🎯 Manual Integration Test Instructions:"
puts ""
puts "To fully test the onboarding module:"
puts "1. Start your Rails server: bin/dev"
puts "2. Create a new user account"
puts "3. Visit /onboarding to start the wizard"
puts "4. Test each step of the onboarding flow"
puts "5. Verify skip and resume functionality"
puts "6. Check that progress is saved correctly"
puts ""
puts "Expected URLs to test:"
puts "- GET /onboarding - Main onboarding entry"
puts "- GET /onboarding/step/welcome - Welcome step"
puts "- GET /onboarding/step/create_workspace - Workspace creation (if workspace module available)"
puts "- GET /onboarding/step/invite_colleagues - Team invitations (if workspace module available)"
puts "- GET /onboarding/step/connect_billing - Billing setup (if billing module available)"
puts "- GET /onboarding/step/connect_ai - AI provider setup (if AI module available)"
puts "- GET /onboarding/step/explore_features - Feature overview"
puts "- GET /onboarding/step/complete - Completion page"
puts ""
puts "Test in Rails console:"
puts "  user = User.first"
puts "  user.start_onboarding!"
puts "  user.onboarding_progress.mark_step_complete('welcome')"
puts "  user.onboarding_progress.progress_percentage"
puts "  user.onboarding_complete?"