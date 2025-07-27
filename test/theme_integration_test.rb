#!/usr/bin/env ruby
# frozen_string_literal: true

# Test that validates the theme module integration with the main template

puts "🎨 Testing Theme Module Integration..."

# Test 1: Verify theme module exists in the expected location
theme_module_path = File.expand_path('../scaffold/lib/templates/synth/theme', __dir__)
puts "✅ Theme module directory exists" if Dir.exist?(theme_module_path)

# Test 2: Verify required files exist
required_files = %w[README.md VERSION install.rb]
required_files.each do |file|
  file_path = File.join(theme_module_path, file)
  if File.exist?(file_path)
    puts "✅ #{file} exists"
  else
    puts "❌ #{file} missing"
    exit 1
  end
end

# Test 3: Verify theme module test exists and passes
theme_test_path = File.join(theme_module_path, 'test', 'theme_module_test.rb')
if File.exist?(theme_test_path)
  puts "✅ Theme module test exists"
  
  # Run the theme module test
  test_result = system("ruby #{theme_test_path}")
  if test_result
    puts "✅ Theme module tests pass"
  else
    puts "❌ Theme module tests failed"
    exit 1
  end
else
  puts "❌ Theme module test missing"
  exit 1
end

# Test 4: Verify template.rb includes theme module
template_path = File.expand_path('../scaffold/template.rb', __dir__)
template_content = File.read(template_path)
if template_content.include?("run 'bin/synth add theme'")
  puts "✅ Theme module included in main template"
else
  puts "❌ Theme module not included in main template"
  exit 1
end

# Test 5: Verify README content includes key sections
readme_path = File.join(theme_module_path, 'README.md')
readme_content = File.read(readme_path)

required_sections = [
  'Theme and Brand Customization',
  '## Features',
  '## Installation',
  '## Usage',
  'CSS Custom Properties',
  'Light/Dark Mode'
]

required_sections.each do |section|
  if readme_content.include?(section)
    puts "✅ README includes '#{section}' section"
  else
    puts "❌ README missing '#{section}' section"
    exit 1
  end
end

# Test 6: Verify install.rb creates expected files
install_path = File.join(theme_module_path, 'install.rb')
install_content = File.read(install_path)

expected_file_creations = [
  '_theme_variables.css',
  'theme.css',
  '_theme_switcher.html.erb',
  '_brand_logo.html.erb',
  'theme_switcher_controller.js',
  'theme_preferences_controller.rb',
  'theme.rb',
  'add_theme_preference_to_users.rb'
]

expected_file_creations.each do |file|
  if install_content.include?(file)
    puts "✅ Install script creates #{file}"
  else
    puts "❌ Install script missing #{file}"
    exit 1
  end
end

# Test 7: Verify CSS variables structure
if install_content.include?('--brand-primary:') && install_content.include?('[data-theme="dark"]')
  puts "✅ CSS variables and dark mode support included"
else
  puts "❌ CSS variables or dark mode support missing"
  exit 1
end

# Test 8: Verify JavaScript theme switching and server sync functionality
if install_content.include?('localStorage.getItem(\'theme\')') && 
   install_content.include?('data-theme') &&
   install_content.include?('syncThemePreference') &&
   install_content.include?('fetch(this.syncUrlValue')
  puts "✅ JavaScript theme switching and server sync functionality included"
else
  puts "❌ JavaScript theme switching or server sync functionality missing"
  exit 1
end

# Test 9: Verify server-side persistence features
if install_content.include?('ThemePreferencesController') &&
   install_content.include?('session[:theme_preference]') &&
   install_content.include?('current_user.theme_preference')
  puts "✅ Server-side theme persistence functionality included"
else
  puts "❌ Server-side theme persistence functionality missing"
  exit 1
end

puts ""
puts "🎉 All theme module integration tests passed!"
puts "📝 Enhanced theme customization framework with server-side persistence is ready for use"
puts ""
puts "Next steps:"
puts "- Add theme module to generated apps with: bin/synth add theme"
puts "- Run migration: rails db:migrate (optional, for database persistence)"
puts "- Customize colors in app/assets/stylesheets/theme.css"
puts "- Add brand logos to app/assets/images/brand/"
puts "- Configure theme settings in config/initializers/theme.rb"
puts "- Theme preferences will persist across sessions and devices"