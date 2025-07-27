# frozen_string_literal: true

# Copy the real Synth CLI implementation to the Rails app
puts "📦 Setting up Synth CLI..."

# Create bin/synth executable
run 'mkdir -p bin'
create_file 'bin/synth', <<~RUBY
  #!/usr/bin/env ruby
  # frozen_string_literal: true

  require_relative '../lib/synth/cli'

  Synth::CLI.start(ARGV)
RUBY
run 'chmod +x bin/synth'

# Copy the complete CLI implementation from the template
cli_source_dir = File.join(__dir__, '..', 'lib', 'synth')
run "mkdir -p lib/synth/commands"

# Copy all CLI files
Dir.glob(File.join(cli_source_dir, '*.rb')).each do |file|
  copy_file file, "lib/synth/#{File.basename(file)}"
end

Dir.glob(File.join(cli_source_dir, 'commands', '*.rb')).each do |file|
  copy_file file, "lib/synth/commands/#{File.basename(file)}"
end

# Copy templates to lib/templates/synth
templates_source_dir = File.join(__dir__, '..', 'lib', 'templates', 'synth')
run "mkdir -p lib/templates/synth"

Dir.glob(File.join(templates_source_dir, '*')).each do |module_dir|
  next unless File.directory?(module_dir)
  module_name = File.basename(module_dir)
  run "cp -r #{module_dir} lib/templates/synth/"
end

# Copy synth modules configuration
config_source = File.join(__dir__, '..', 'config', 'synth_modules.json')
run "mkdir -p config"
copy_file config_source, 'config/synth_modules.json' if File.exist?(config_source)

puts "✅ Synth CLI setup complete"
