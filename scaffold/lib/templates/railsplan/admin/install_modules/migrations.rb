# frozen_string_literal: true

# Admin module migrations installer
# This modular installer handles database migrations

say_status :admin_migrations, "Setting up admin migrations"

# Create Flipper migration
generate "flipper:active_record"

# Create admin-specific audit log migration
migration_template 'admin_enhancements.rb', 'db/migrate/add_admin_enhancements.rb'

say_status :admin_migrations, "Admin migrations created"