# frozen_string_literal: true

# Copy the real RailsPlan CLI implementation to the Rails app
puts "📦 Setting up RailsPlan CLI..."

# Create bin/railsplan executable
run 'mkdir -p bin'
create_file 'bin/railsplan', <<~RUBY
  #!/usr/bin/env ruby
  # frozen_string_literal: true

  require_relative '../lib/railsplan/cli'

  RailsPlan::CLI.start(ARGV)
RUBY
run 'chmod +x bin/railsplan'

# Copy the complete CLI implementation from the template
cli_source_dir = File.join(__dir__, '..', 'lib', 'railsplan')
run "mkdir -p lib/railsplan/commands"

# Copy all CLI files
Dir.glob(File.join(cli_source_dir, '*.rb')).each do |file|
  copy_file file, "lib/railsplan/#{File.basename(file)}"
end

Dir.glob(File.join(cli_source_dir, 'commands', '*.rb')).each do |file|
  copy_file file, "lib/railsplan/commands/#{File.basename(file)}"
end

# Copy templates to lib/templates/railsplan
templates_source_dir = File.join(__dir__, '..', 'lib', 'templates', 'railsplan')
run "mkdir -p lib/templates/railsplan"

Dir.glob(File.join(templates_source_dir, '*')).each do |module_dir|
  next unless File.directory?(module_dir)
  module_name = File.basename(module_dir)
  run "cp -r #{module_dir} lib/templates/railsplan/"
end

# Copy railsplan modules configuration
config_source = File.join(__dir__, '..', 'config', 'railsplan_modules.json')
run "mkdir -p config"
copy_file config_source, 'config/railsplan_modules.json' if File.exist?(config_source)

puts "✅ RailsPlan CLI setup complete"
