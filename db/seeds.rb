# frozen_string_literal: true

# Main seeds file for Rails SaaS Starter Template
# Loads all seed files from db/seeds/ directory

puts "🌱 Starting seed process..."

# Load all seed files from db/seeds/ directory
seed_files = Dir[File.join(Rails.root, 'db', 'seeds', '*.rb')].sort

if seed_files.any?
  puts "📁 Found #{seed_files.length} seed file(s):"
  seed_files.each { |file| puts "   • #{File.basename(file)}" }
  puts ""
  
  seed_files.each do |seed_file|
    puts "▶️  Loading #{File.basename(seed_file)}..."
    load seed_file
    puts ""
  end
else
  puts "⚠️  No seed files found in db/seeds/"
end

puts "✨ Seed process completed!"