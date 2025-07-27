# frozen_string_literal: true

# Removal script for the Notifications module.
# This script removes the Notifications module and cleans up related files.

say 'Removing Notifications module...'

# Remove domain directories
run 'rm -rf app/domains/notifications'
run 'rm -rf spec/domains/notifications'

# Remove routes
routes_content = File.read('config/routes.rb')
if routes_content.include?('resources :notifications')
  say 'Removing notification routes...'
  
  # Remove the notifications routes block
  routes_to_remove = <<~ROUTES
    scope module: :notifications do
      resources :notifications, only: [:index, :show, :update, :destroy] do
        member do
          patch :read
          patch :dismiss
        end
        
        collection do
          patch :mark_all_read
          delete :dismiss_all
        end
      end
      
      resource :notification_preferences, only: [:show, :update]
    end
  ROUTES
  
  new_routes = routes_content.gsub(routes_to_remove, '')
  File.write('config/routes.rb', new_routes)
end

# Remove configuration
config_file = 'config/initializers/notifications.rb'
if File.exist?(config_file)
  say 'Removing notification configuration...'
  File.delete(config_file)
end

# Remove CSS
css_file = 'app/assets/stylesheets/notifications.css'
if File.exist?(css_file)
  say 'Removing notification styles...'
  File.delete(css_file)
end

# Remove CSS import from application.css
application_css_path = 'app/assets/stylesheets/application.css'
if File.exist?(application_css_path)
  application_css_content = File.read(application_css_path)
  if application_css_content.include?("@import 'notifications.css';")
    new_content = application_css_content.gsub("\n@import 'notifications.css';\n", '')
    File.write(application_css_path, new_content)
  end
end

# Remove User model extensions
user_model_path = 'app/models/user.rb'
if File.exist?(user_model_path)
  user_content = File.read(user_model_path)
  if user_content.include?('has_many :notifications')
    say 'Removing notification associations from User model...'
    
    # Remove the notification-related code block
    code_to_remove = <<~RUBY
        # Notification associations
        has_many :notifications, dependent: :destroy
        has_one :notification_preference, dependent: :destroy
        
        # Notification methods
        def unread_notifications_count
          notifications.unread.count
        end
        
        def create_notification_preference!
          self.notification_preference ||= NotificationPreference.create!(
            user: self,
            email_notifications: true,
            in_app_notifications: true,
            notification_types: NotificationPreference.default_preferences
          )
        end
        
        after_create :create_notification_preference!
    RUBY
    
    new_user_content = user_content.gsub(code_to_remove, '')
    File.write(user_model_path, new_user_content)
  end
end

# Generate removal migration
say 'Generating migration to drop notification tables...'
generate :migration, 'DropNotificationTables', <<~MIGRATION
  def up
    drop_table :notifications if table_exists?(:notifications)
    drop_table :notification_preferences if table_exists?(:notification_preferences)
  end
  
  def down
    # Recreating tables would require the original migration files
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate notification tables"
  end
MIGRATION

say 'Notifications module removal complete!'
say ''
say 'Next steps:'
say '1. Run: rails db:migrate'
say '2. Remove any notification-related code from your controllers'
say '3. Remove notification bell from your layout if you added it'
say '4. Update any custom code that references NotificationService'
say ''
say 'Note: This removal script cannot undo all customizations you may have made.'
say 'Please review your codebase for any remaining notification-related code.'