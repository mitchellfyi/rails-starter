#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple validation script for API module structure
# Verifies that all files are present and syntactically correct

require 'pathname'

def validate_file(path, description, check_syntax: true)
  path_str = path.to_s
  if File.exist?(path_str)
    if check_syntax && path_str.end_with?('.rb')
      begin
        # Basic Ruby syntax check for .rb files only
        `ruby -c "#{path_str}" 2>&1`
        if $?.success?
          puts "✅ #{description} - syntax OK"
          true
        else
          puts "❌ #{description} - syntax error"
          false
        end
      rescue => e
        puts "❌ #{description} - error: #{e.message}"
        false
      end
    else
      puts "✅ #{description} - file exists"
      true
    end
  else
    puts "❌ #{description} - file missing"
    false
  end
end

def validate_directory(path, description)
  if Dir.exist?(path)
    puts "✅ #{description} - directory exists"
    true
  else
    puts "❌ #{description} - directory missing"
    false
  end
end

puts "🔍 Validating API Module Structure..."
puts

base_path = Pathname.new(__dir__)
api_path = base_path / 'lib' / 'templates' / 'synth' / 'api'

all_valid = true

# Check main module files
all_valid &= validate_file(api_path / 'install.rb', 'API module installer')
all_valid &= validate_file(api_path / 'README.md', 'API module documentation', check_syntax: false)

# Check CLI integration
all_valid &= validate_file(base_path / 'lib' / 'synth' / 'cli.rb', 'Synth CLI')

# Check template structure
all_valid &= validate_directory(base_path / 'lib' / 'templates' / 'synth', 'Synth templates directory')
all_valid &= validate_directory(api_path, 'API module directory')

puts
if all_valid
  puts "🎉 All API module files are valid!"
  puts
  puts "Available modules:"
  Dir.glob(base_path / 'lib' / 'templates' / 'synth' / '*').each do |module_dir|
    if File.directory?(module_dir)
      module_name = File.basename(module_dir)
      readme_path = File.join(module_dir, 'README.md')
      
      if File.exist?(readme_path)
        first_line = File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '')
        puts "  #{module_name.ljust(8)} - #{first_line}"
      else
        puts "  #{module_name}"
      end
    end
  end
  
  puts
  puts "To use the API module in a Rails app:"
  puts "  bin/synth add api"
  
  exit 0
else
  puts "❌ Some validation checks failed"
  exit 1
end