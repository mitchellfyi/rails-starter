# Seed data for admin panel functionality
require_relative '../../lib/seed_i18n_helper'

puts "🌱 Seeding Admin data..."
SeedI18nHelper.puts_i18n_status

# Create default feature flags
default_flags = [
  {
    name: 'new_ui',
    description: SeedI18nHelper.seed_translation('seeds.feature_flags.new_ui.description', fallback: 'Enable the new user interface design'),
    enabled: false
  },
  {
    name: 'beta_features',
    description: SeedI18nHelper.seed_translation('seeds.feature_flags.beta_features.description', fallback: 'Enable beta features for testing'),
    enabled: false
  },
  {
    name: 'ai_chat',
    description: SeedI18nHelper.seed_translation('seeds.feature_flags.ai_chat.description', fallback: 'Enable AI chat functionality'),
    enabled: true
  },
  {
    name: 'workspace_analytics',
    description: SeedI18nHelper.seed_translation('seeds.feature_flags.workspace_analytics.description', fallback: 'Enable workspace analytics dashboard'),
    enabled: false
  }
]

default_flags.each do |flag_data|
  flag = FeatureFlag.find_or_create_by(name: flag_data[:name]) do |f|
    f.description = flag_data[:description]
    f.enabled = flag_data[:enabled]
  end
  
  puts "✅ Feature flag '#{flag.name}' ready (#{flag.enabled? ? 'enabled' : 'disabled'})"
end

# Create sample audit log if none exist
if AuditLog.count == 0
  AuditLog.create!(
    action: 'system_setup',
    description: SeedI18nHelper.seed_translation('seeds.audit_logs.system_setup.description', fallback: 'Admin panel initialized with default feature flags'),
    metadata: { flags_created: default_flags.count }
  )
  puts "✅ Initial audit log created"
end

puts "🎯 Admin panel seed data ready!"