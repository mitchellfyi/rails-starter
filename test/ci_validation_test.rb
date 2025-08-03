#!/usr/bin/env ruby
# Test script to validate railsplan CI commands

require_relative '../lib/railsplan/commands/doctor_command'
require_relative '../lib/railsplan/commands/verify_command'

puts "🧪 Testing RailsPlan CI Commands\n\n"

# Test doctor command
puts "Testing doctor --ci command:"
doctor = RailsPlan::Commands::DoctorCommand.new(verbose: false)
doctor_result = doctor.execute(ci: true)

puts "\nDoctor result: #{doctor_result ? '✅ PASSED' : '❌ FAILED'}"

if File.exist?('.railsplan/doctor_report.json')
  puts "📄 Doctor report generated successfully"
else
  puts "❌ Doctor report missing"
end

puts "\n" + "="*50 + "\n"

# Test verify command  
puts "Testing verify --ci command:"
verify = RailsPlan::Commands::VerifyCommand.new(verbose: false)
verify_result = verify.execute(ci: true)

puts "\nVerify result: #{verify_result ? '✅ PASSED' : '❌ FAILED'}"

if File.exist?('.railsplan/verify_report.json')
  puts "📄 Verify report generated successfully"
else
  puts "❌ Verify report missing"
end

puts "\n" + "="*50 + "\n"

puts "🏁 Test Summary:"
puts "  Doctor: #{doctor_result ? '✅' : '❌'}"
puts "  Verify: #{verify_result ? '✅' : '❌'}"

# Show report contents if available
if File.exist?('.railsplan/doctor_report.json')
  puts "\n📊 Doctor Report:"
  puts File.read('.railsplan/doctor_report.json')
end

if File.exist?('.railsplan/verify_report.json')
  puts "\n📊 Verify Report:"
  puts File.read('.railsplan/verify_report.json')
end

puts "\n✅ All tests completed!"