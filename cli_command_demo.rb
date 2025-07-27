#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to demonstrate CLI command availability and help text

puts "🔧 Rails SaaS Starter CLI - Bootstrap Command Demo"
puts "=" * 52
puts ""

puts "The new 'bootstrap' command has been added to the Synth CLI."
puts "Here's how developers can access and use it:"
puts ""

puts "1️⃣ View Available Commands"
puts "-" * 26
puts "   $ ./bin/synth"
puts ""

puts "2️⃣ Get Help for Bootstrap Command"
puts "-" * 33
puts "   $ ./bin/synth help bootstrap"
puts ""

puts "3️⃣ Run the Interactive Bootstrap Wizard"
puts "-" * 40
puts "   $ ./bin/synth bootstrap"
puts ""

# Simulate the CLI command structure by reading the actual CLI file
cli_content = File.read('lib/synth/cli.rb')

# Extract the bootstrap command description
if cli_content =~ /desc\s+['"]bootstrap['"],\s*['"]([^'"]+)['"]/
  bootstrap_desc = $1
  puts "Bootstrap Command Description:"
  puts "   #{bootstrap_desc}"
  puts ""
end

# Show command options
puts "Available Options:"
puts "   --skip-modules      Skip module selection"
puts "   --skip-credentials  Skip API credentials setup" 
puts "   --verbose, -v       Enable verbose output"
puts ""

puts "🎯 Integration with Existing Commands"
puts "-" * 36
puts ""
puts "The bootstrap command works alongside existing Synth CLI commands:"
puts ""

# Extract existing command descriptions
existing_commands = []
cli_content.scan(/desc\s+['"]([^'"]+)['"],\s*['"]([^'"]+)['"]/) do |cmd, desc|
  next if cmd == 'bootstrap' # Skip bootstrap since we already showed it
  existing_commands << "   #{cmd.ljust(12)} - #{desc}"
end

existing_commands.each { |cmd| puts cmd }

puts ""
puts "💡 Typical Development Workflow"
puts "-" * 31
puts ""
puts "1. New project setup:"
puts "   $ git clone <rails-starter-template>"
puts "   $ cd my-saas-project"
puts "   $ ./bin/synth doctor          # Check prerequisites"
puts "   $ ./bin/synth bootstrap       # Interactive setup"
puts ""
puts "2. Add features later:"
puts "   $ ./bin/synth list            # See available modules"
puts "   $ ./bin/synth add ai          # Add AI features"
puts "   $ ./bin/synth info billing    # Learn about billing module"
puts ""
puts "3. Maintenance and updates:"
puts "   $ ./bin/synth doctor          # Health check"
puts "   $ ./bin/synth upgrade         # Update all modules"
puts "   $ ./bin/synth test            # Run tests"
puts ""

puts "📚 Documentation"
puts "-" * 16
puts ""
puts "• Full documentation: BOOTSTRAP_CLI.md"
puts "• Usage examples: bootstrap_usage_examples.rb"
puts "• Demo output: demo_bootstrap.rb"
puts ""

puts "✅ The Interactive Bootstrap CLI is ready for use!"