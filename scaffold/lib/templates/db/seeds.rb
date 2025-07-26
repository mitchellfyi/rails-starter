# frozen_string_literal: true

# Rails SaaS Starter Template Seeds
# This file should be idempotent and safe to run multiple times.
# It creates demo data for development and testing.

puts "🌱 Seeding Rails SaaS Starter Template..."

# Helper method to find or create records idempotently
def find_or_create_by_with_attributes(model, find_attributes, create_attributes = {})
  record = model.find_by(find_attributes)
  unless record
    record = model.create!(find_attributes.merge(create_attributes))
    puts "   ✅ Created #{model.name}: #{record.try(:name) || record.try(:email) || record.id}"
  else
    puts "   ⏭️  Found existing #{model.name}: #{record.try(:name) || record.try(:email) || record.id}"
  end
  record
end

# Create demo organization and user
puts "\n👤 Creating demo user and organization..."

# Create demo user with confirmed email
demo_user = find_or_create_by_with_attributes(
  User,
  { email: 'demo@example.com' },
  {
    password: 'password123',
    password_confirmation: 'password123',
    confirmed_at: Time.current,
    first_name: 'Demo',
    last_name: 'User'
  }
)

# Create demo workspace
demo_workspace = find_or_create_by_with_attributes(
  Workspace,
  { slug: 'demo-workspace' },
  {
    name: 'Demo Workspace',
    description: 'A sample workspace for development and testing'
  }
)

# Create membership connecting user to workspace
find_or_create_by_with_attributes(
  Membership,
  { user: demo_user, workspace: demo_workspace },
  { role: 'admin' }
)

# Load module-specific seeds
puts "\n🔌 Loading module seeds..."

# AI Module Seeds
if defined?(PromptTemplate) && defined?(LLMJob)
  puts "\n🤖 Seeding AI module data..."
  load Rails.root.join('db', 'seeds', 'ai_seeds.rb')
end

# Billing Module Seeds  
if defined?(Plan) && defined?(Product)
  puts "\n💳 Seeding billing module data..."
  load Rails.root.join('db', 'seeds', 'billing_seeds.rb')
end

# CMS Module Seeds
if defined?(Post) || defined?(BlogPost)
  puts "\n📝 Seeding CMS module data..."
  load Rails.root.join('db', 'seeds', 'cms_seeds.rb')
end

puts "\n✅ Seeding complete! Demo user: demo@example.com / password123"
puts "   Visit your app and sign in to explore the demo data."