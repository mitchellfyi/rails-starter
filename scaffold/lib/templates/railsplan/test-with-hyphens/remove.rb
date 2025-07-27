# frozen_string_literal: true

# TestWithHyphens module removal script for the Rails SaaS starter template.
# This script is executed by the bin/railsplan CLI when removing the test-with-hyphens module.

say_status :test-with-hyphens, "Removing TestWithHyphens module"

# Remove initializer
initializer_file = 'config/initializers/test-with-hyphens.rb'
if File.exist?(initializer_file)
  remove_file initializer_file
  say_status :test-with-hyphens, "Removed initializer"
end

# Remove routes (you may need to customize this)
routes_file = 'config/routes.rb'
if File.exist?(routes_file)
  # This is a basic example - you may need more sophisticated route removal
  # depending on how your module adds routes
  gsub_file routes_file, /\s*# TestWithHyphens module routes.*?# End TestWithHyphens module routes\s*/m, ''
  say_status :test-with-hyphens, "Cleaned up routes"
end

# Note: Migrations are not automatically removed to prevent data loss
# Users should manually review and remove migrations if appropriate

say_status :test-with-hyphens, "✅ TestWithHyphens module removed successfully!"
say_status :test-with-hyphens, "⚠️  Database migrations were not removed automatically"
say_status :test-with-hyphens, "   Review db/migrate/ and remove test-with-hyphens migrations if appropriate"
say_status :test-with-hyphens, "   Run 'rails db:rollback' to undo recent migrations if needed"
