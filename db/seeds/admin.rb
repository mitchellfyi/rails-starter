# Seed data for admin panel functionality

# Create default feature flags
default_flags = [
  {
    name: 'new_ui',
    description: 'Enable the new user interface design',
    enabled: false
  },
  {
    name: 'beta_features',
    description: 'Enable beta features for testing',
    enabled: false
  },
  {
    name: 'ai_chat',
    description: 'Enable AI chat functionality',
    enabled: true
  },
  {
    name: 'workspace_analytics',
    description: 'Enable workspace analytics dashboard',
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
    description: 'Admin panel initialized with default feature flags',
    metadata: { flags_created: default_flags.count }
  )
  puts "✅ Initial audit log created"
end

puts "🎯 Admin panel seed data ready!"