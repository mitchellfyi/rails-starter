#!/usr/bin/env ruby
# frozen_string_literal: true

# Example usage script for the Bootstrap CLI
# This shows how developers would use the new bootstrap command

puts "📋 Rails SaaS Starter - Bootstrap CLI Usage Examples"
puts "=" * 55
puts ""

puts "The new bootstrap command provides an interactive wizard to set up"
puts "your Rails SaaS application. Here are some usage examples:"
puts ""

puts "1️⃣ Basic Bootstrap (Full Interactive Setup)"
puts "-" * 43
puts "   ./bin/synth bootstrap"
puts ""
puts "   This runs the full interactive wizard that prompts for:"
puts "   • Application configuration (name, domain, environment)"  
puts "   • Team setup (name, owner email, admin password)"
puts "   • Module selection (ai, billing, cms, etc.)"
puts "   • API credentials for selected modules"
puts "   • LLM provider preferences for AI features"
puts ""

puts "2️⃣ Skip Module Selection"
puts "-" * 24
puts "   ./bin/synth bootstrap --skip-modules"
puts ""
puts "   Runs the wizard but skips module installation."
puts "   You can add modules later with: ./bin/synth add <module>"
puts ""

puts "3️⃣ Skip Credentials Setup"
puts "-" * 26
puts "   ./bin/synth bootstrap --skip-credentials"
puts ""
puts "   Runs the wizard but skips API credentials collection."
puts "   You can add credentials manually to the .env file later."
puts ""

puts "4️⃣ Minimal Setup (Skip Both Modules and Credentials)"
puts "-" * 52
puts "   ./bin/synth bootstrap --skip-modules --skip-credentials"
puts ""
puts "   Minimal setup that only configures basic app and team settings."
puts "   Good for getting started quickly and adding features incrementally."
puts ""

puts "5️⃣ Verbose Output"
puts "-" * 17
puts "   ./bin/synth bootstrap --verbose"
puts ""
puts "   Shows detailed output during the bootstrap process."
puts "   Useful for debugging or understanding what's happening."
puts ""

puts "📖 After Bootstrap Completion"
puts "-" * 29
puts ""
puts "Once bootstrap completes, you'll have:"
puts "✅ Configured .env file with your settings"
puts "✅ Database seeds for admin user and team"
puts "✅ Selected modules installed and configured"
puts "✅ API integrations ready to use"
puts ""
puts "Follow the post-bootstrap steps:"
puts "1. rails db:create db:migrate db:seed"
puts "2. rails server"
puts "3. Visit your admin panel with the generated credentials"
puts ""

puts "🔧 Integration with Existing CLI"
puts "-" * 32
puts ""
puts "The bootstrap command works alongside existing Synth CLI commands:"
puts ""
puts "• List modules:          ./bin/synth list"
puts "• Add module:            ./bin/synth add billing"
puts "• Remove module:         ./bin/synth remove ai"
puts "• Check system health:   ./bin/synth doctor"
puts "• Module information:    ./bin/synth info ai"
puts "• Run tests:             ./bin/synth test"
puts ""

puts "💡 Pro Tips"
puts "-" * 11
puts ""
puts "• Run 'synth doctor' before bootstrap to check prerequisites"
puts "• Keep your .env file secure - never commit it to version control"
puts "• Use the generated admin password immediately and consider changing it"
puts "• Review module documentation after installation"
puts "• Test your API integrations after setup"
puts ""

puts "🎯 Quick Start Workflow"
puts "-" * 23
puts ""
puts "For new projects, follow this workflow:"
puts ""
puts "1. Clone the Rails SaaS Starter template"
puts "2. cd into your project directory"
puts "3. Run: ./bin/synth doctor (check prerequisites)"
puts "4. Run: ./bin/synth bootstrap (interactive setup)"
puts "5. Run: rails db:create db:migrate db:seed"
puts "6. Run: rails server"
puts "7. Start building your SaaS application!"
puts ""

puts "For more information, see BOOTSTRAP_CLI.md documentation."