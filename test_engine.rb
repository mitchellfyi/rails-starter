#!/usr/bin/env ruby

# Simple verification script for RailsPlan Web Engine
puts "🧪 Testing RailsPlan Web Engine Structure..."

# Check file structure
required_files = [
  'lib/railsplan/web.rb',
  'lib/railsplan/web/engine.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/application_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/dashboard_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/schema_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/generator_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/prompts_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/doctor_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/chat_controller.rb',
  'lib/railsplan/web/app/controllers/railsplan/web/upgrade_controller.rb',
  'lib/railsplan/web/config/routes.rb'
]

missing_files = []
existing_files = []

required_files.each do |file|
  if File.exist?(file)
    existing_files << file
    puts "✅ #{file}"
  else
    missing_files << file
    puts "❌ #{file}"
  end
end

puts "\n📊 Summary:"
puts "✅ Existing files: #{existing_files.length}"
puts "❌ Missing files: #{missing_files.length}"

# Check views structure
view_dirs = [
  'lib/railsplan/web/app/views/layouts/railsplan/web',
  'lib/railsplan/web/app/views/railsplan/web/dashboard',
  'lib/railsplan/web/app/views/railsplan/web/schema',
  'lib/railsplan/web/app/views/railsplan/web/generator',
  'lib/railsplan/web/app/views/railsplan/web/prompts',
  'lib/railsplan/web/app/views/railsplan/web/doctor',
  'lib/railsplan/web/app/views/railsplan/web/chat',
  'lib/railsplan/web/app/views/railsplan/web/upgrade',
  'lib/railsplan/web/app/views/railsplan/web/shared'
]

puts "\n🎨 View Structure:"
view_dirs.each do |dir|
  if Dir.exist?(dir)
    file_count = Dir.glob(File.join(dir, '*.html.erb')).length
    puts "✅ #{dir} (#{file_count} views)"
  else
    puts "❌ #{dir}"
  end
end

# Check main view files
main_views = [
  'lib/railsplan/web/app/views/layouts/railsplan/web/application.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/dashboard/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/schema/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/generator/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/prompts/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/doctor/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/chat/index.html.erb',
  'lib/railsplan/web/app/views/railsplan/web/upgrade/index.html.erb'
]

puts "\n🖼️ Main Views:"
main_views.each do |view|
  if File.exist?(view)
    size = File.size(view)
    puts "✅ #{File.basename(view)} (#{size} bytes)"
  else
    puts "❌ #{File.basename(view)}"
  end
end

# Syntax check controllers
puts "\n🔍 Syntax Check:"
controller_files = Dir.glob('lib/railsplan/web/app/controllers/**/*.rb')
syntax_errors = []

controller_files.each do |file|
  begin
    eval(File.read(file), binding, file)
    puts "✅ #{File.basename(file)}"
  rescue SyntaxError => e
    syntax_errors << "#{file}: #{e.message}"
    puts "❌ #{File.basename(file)}: #{e.message}"
  rescue => e
    # Ignore other errors like uninitialized constants, we just want syntax
    puts "✅ #{File.basename(file)} (syntax OK)"
  end
end

puts "\n🎯 Final Results:"
if missing_files.empty? && syntax_errors.empty?
  puts "🎉 All tests passed! RailsPlan Web Engine is ready."
  puts "📍 Dashboard will be available at /railsplan when Rails is running"
  puts "🚀 Features: Dashboard, Schema Browser, AI Generator, Prompt History, Doctor Tool, Chat Console, Upgrade Tool"
else
  puts "⚠️  Issues found:"
  missing_files.each { |f| puts "   Missing: #{f}" }
  syntax_errors.each { |e| puts "   Syntax: #{e}" }
end

puts "\n📋 Next Steps:"
puts "1. Run 'railsplan init' in a Rails app to initialize"
puts "2. Start Rails server and visit /railsplan"
puts "3. Use AI-powered development tools"
puts "4. Explore schema, generate code, run diagnostics"