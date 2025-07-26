# frozen_string_literal: true

# Installer for the Notifications module.
# This module provides a comprehensive notification system with in-app and email notifications.

say 'Installing Notifications module...'

# Create domain-specific directories
run 'mkdir -p app/domains/notifications/app/{controllers,models,mailers,jobs,views/notifications,views/notification_mailer,views/notification_preferences}'
run 'mkdir -p app/domains/notifications/app/javascript/controllers'
run 'mkdir -p spec/domains/notifications/{models,controllers,jobs,mailers,integration,fixtures}'

# Add required gems if not already present
gems_to_add = []

unless File.read('Gemfile').include?('sidekiq')
  gems_to_add << ['sidekiq', '~> 7.0']
end

unless gems_to_add.empty?
  say 'Adding required gems...'
  gems_to_add.each do |gem_name, version|
    gem gem_name, version
  end
  run 'bundle install'
end

# Generate models (skip if they already exist)
if File.exist?('app/models/notification.rb') || File.exist?('app/domains/notifications/app/models/notification.rb')
  say 'Notification model already exists, skipping generation...'
else
  generate :model, 'Notification', 
    'user:references', 
    'notification_type:string', 
    'title:string', 
    'message:text', 
    'data:json', 
    'read_at:datetime', 
    'dismissed_at:datetime',
    dir: 'app/domains/notifications/app/models'
end

if File.exist?('app/models/notification_preference.rb') || File.exist?('app/domains/notifications/app/models/notification_preference.rb')
  say 'NotificationPreference model already exists, skipping generation...'
else
  generate :model, 'NotificationPreference',
    'user:references',
    'email_notifications:boolean',
    'in_app_notifications:boolean', 
    'notification_types:json',
    dir: 'app/domains/notifications/app/models'
end

# Generate controllers
generate :controller, 'Notifications', 'index', 'show', 'update', 'destroy', dir: 'app/domains/notifications/app/controllers' unless File.exist?('app/controllers/notifications_controller.rb')
generate :controller, 'NotificationPreferences', 'show', 'update', dir: 'app/domains/notifications/app/controllers' unless File.exist?('app/controllers/notification_preferences_controller.rb')

# Generate mailer
generate :mailer, 'NotificationMailer', 'notification_email', dir: 'app/domains/notifications/app/mailers' unless File.exist?('app/mailers/notification_mailer.rb')

# Generate background jobs
generate :job, 'NotificationJob', dir: 'app/domains/notifications/app/jobs' unless File.exist?('app/jobs/notification_job.rb')
generate :job, 'BulkNotificationJob', dir: 'app/domains/notifications/app/jobs' unless File.exist?('app/jobs/bulk_notification_job.rb')

# Add routes (check if routes don't already exist)
routes_content = File.read('config/routes.rb')
unless routes_content.include?('resources :notifications')
  route <<~ROUTES
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
end

# Copy enhanced model files
say 'Copying enhanced model files...'
template_dir = File.expand_path('lib/templates/synth/notifications', Rails.root)

copy_file File.join(template_dir, 'app/models/notification.rb'), 'app/domains/notifications/app/models/notification.rb', force: true
copy_file File.join(template_dir, 'app/models/notification_preference.rb'), 'app/domains/notifications/app/models/notification_preference.rb', force: true

# Copy controllers
copy_file File.join(template_dir, 'app/controllers/notifications_controller.rb'), 'app/domains/notifications/app/controllers/notifications_controller.rb', force: true
copy_file File.join(template_dir, 'app/controllers/notification_preferences_controller.rb'), 'app/domains/notifications/app/controllers/notification_preferences_controller.rb', force: true

# Copy mailer
copy_file File.join(template_dir, 'app/mailers/notification_mailer.rb'), 'app/domains/notifications/app/mailers/notification_mailer.rb', force: true

# Copy jobs
copy_file File.join(template_dir, 'app/jobs/notification_job.rb'), 'app/domains/notifications/app/jobs/notification_job.rb', force: true
copy_file File.join(template_dir, 'app/jobs/bulk_notification_job.rb'), 'app/domains/notifications/app/jobs/bulk_notification_job.rb', force: true

# Copy service
run 'mkdir -p app/domains/notifications/app/services'
copy_file File.join(template_dir, 'app/services/notification_service.rb'), 'app/domains/notifications/app/services/notification_service.rb', force: true

# Copy views
directory File.join(template_dir, 'app/views'), 'app/domains/notifications/app/views'

# Copy JavaScript controllers
directory File.join(template_dir, 'app/javascript'), 'app/domains/notifications/app/javascript'

# Copy configuration
copy_file File.join(template_dir, 'config/initializers/notifications.rb'), 'config/initializers/notifications.rb', force: true

# Update User model to include notification extensions
user_model_path = 'app/models/user.rb'
if File.exist?(user_model_path)
  user_content = File.read(user_model_path)
  unless user_content.include?('has_many :notifications')
    say 'Adding notification associations to User model...'
    inject_into_class user_model_path, 'User' do
      <<~RUBY
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
    end
  end
end

# Add CSS for notifications
say 'Adding notification styles...'
create_file 'app/assets/stylesheets/notifications.css', <<~CSS
  /* Notification styles */
  .notification-toast {
    @apply fixed top-4 right-4 z-50 max-w-sm bg-white border border-gray-200 rounded-lg shadow-lg transform transition-all duration-300;
  }
  
  .notification-toast.entering {
    @apply translate-x-full opacity-0;
  }
  
  .notification-toast.entered {
    @apply translate-x-0 opacity-100;
  }
  
  .notification-toast.exiting {
    @apply translate-x-full opacity-0;
  }
  
  .notification-feed {
    @apply max-h-96 overflow-y-auto;
  }
  
  .notification-item {
    @apply border-b border-gray-100 p-4 hover:bg-gray-50 transition-colors duration-150;
  }
  
  .notification-item.unread {
    @apply bg-blue-50 border-l-4 border-l-blue-500;
  }
  
  .notification-badge {
    @apply inline-flex items-center justify-center w-5 h-5 text-xs font-bold text-white bg-red-500 rounded-full;
  }
CSS

# Import notification styles in application.css
application_css_path = 'app/assets/stylesheets/application.css'
if File.exist?(application_css_path)
  application_css_content = File.read(application_css_path)
  unless application_css_content.include?('notifications.css')
    append_to_file application_css_path, "\n@import 'notifications.css';\n"
  end
end

say 'Notifications module installation complete!'
say ''
say 'Next steps:'
say '1. Run: rails db:migrate'
say '2. Configure notification types in config/initializers/notifications.rb'
say '3. Add notification components to your layout (see README.md)'
say '4. Set up Sidekiq for background job processing'
say '5. Configure email delivery in your environment files'
say ''
say 'For more information, see: app/domains/notifications/README.md'