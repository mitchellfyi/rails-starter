# frozen_string_literal: true

# DemoFeature module removal script for the Rails SaaS starter template.
# This script is executed by the bin/railsplan CLI when removing the demo_feature module.

say_status :demo_feature, "Removing DemoFeature module"

# Remove initializer
initializer_file = 'config/initializers/demo_feature.rb'
if File.exist?(initializer_file)
  remove_file initializer_file
  say_status :demo_feature, "Removed initializer"
end

# Remove routes (you may need to customize this)
routes_file = 'config/routes.rb'
if File.exist?(routes_file)
  # This is a basic example - you may need more sophisticated route removal
  # depending on how your module adds routes
  gsub_file routes_file, /\s*# DemoFeature module routes.*?# End DemoFeature module routes\s*/m, ''
  say_status :demo_feature, "Cleaned up routes"
end

# Note: Migrations are not automatically removed to prevent data loss
# Users should manually review and remove migrations if appropriate

say_status :demo_feature, "✅ DemoFeature module removed successfully!"
say_status :demo_feature, "⚠️  Database migrations were not removed automatically"
say_status :demo_feature, "   Review db/migrate/ and remove demo_feature migrations if appropriate"
say_status :demo_feature, "   Run 'rails db:rollback' to undo recent migrations if needed"
