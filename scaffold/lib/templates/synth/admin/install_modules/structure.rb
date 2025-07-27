# frozen_string_literal: true

# Admin module directory structure installer
# This modular installer creates the necessary directory structure

say_status :admin_structure, "Creating admin directory structure"

# Create domain-specific directories
run 'mkdir -p app/domains/admin/app/controllers/admin'
run 'mkdir -p app/domains/admin/app/policies'
run 'mkdir -p app/domains/admin/app/views/admin/dashboard'
run 'mkdir -p app/domains/admin/app/views/admin/users'
run 'mkdir -p app/domains/admin/app/views/admin/audit_logs'
run 'mkdir -p app/domains/admin/app/views/admin/feature_flags'
run 'mkdir -p app/domains/admin/app/views/layouts'
run 'mkdir -p app/models/concerns'

say_status :admin_structure, "Admin directory structure created"