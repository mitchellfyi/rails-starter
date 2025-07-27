# frozen_string_literal: true

# TestFeature module removal script for the Rails SaaS starter template.
# This script is executed by the bin/railsplan CLI when removing the test_feature module.

say_status :test_feature, "Removing TestFeature module"

# Remove initializer
initializer_file = 'config/initializers/test_feature.rb'
if File.exist?(initializer_file)
  remove_file initializer_file
  say_status :test_feature, "Removed initializer"
end

# Remove routes (you may need to customize this)
routes_file = 'config/routes.rb'
if File.exist?(routes_file)
  # This is a basic example - you may need more sophisticated route removal
  # depending on how your module adds routes
  gsub_file routes_file, /\s*# TestFeature module routes.*?# End TestFeature module routes\s*/m, ''
  say_status :test_feature, "Cleaned up routes"
end

# Note: Migrations are not automatically removed to prevent data loss
# Users should manually review and remove migrations if appropriate

say_status :test_feature, "✅ TestFeature module removed successfully!"
say_status :test_feature, "⚠️  Database migrations were not removed automatically"
say_status :test_feature, "   Review db/migrate/ and remove test_feature migrations if appropriate"
say_status :test_feature, "   Run 'rails db:rollback' to undo recent migrations if needed"
