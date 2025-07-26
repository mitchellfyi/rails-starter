#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for the Notifications module
# Validates the module structure and basic functionality

require 'test/unit'

class NotificationsModuleTest < Test::Unit::TestCase
  def setup
    @module_path = File.expand_path('../scaffold/lib/templates/synth/notifications', __dir__)
  end

  def test_module_directory_exists
    assert File.directory?(@module_path), "Notifications module directory should exist at #{@module_path}"
  end

  def test_required_files_exist
    required_files = [
      'README.md',
      'VERSION',
      'install.rb',
      'app/models/notification.rb',
      'app/models/notification_preference.rb',
      'app/controllers/notifications_controller.rb',
      'app/controllers/notification_preferences_controller.rb',
      'app/mailers/notification_mailer.rb',
      'app/jobs/notification_job.rb',
      'app/jobs/bulk_notification_job.rb',
      'app/services/notification_service.rb',
      'app/views/notifications/index.html.erb',
      'app/views/notification_preferences/show.html.erb',
      'app/javascript/controllers/notifications_controller.js',
      'app/javascript/controllers/notification_toast_controller.js',
      'config/initializers/notifications.rb'
    ]

    required_files.each do |file|
      file_path = File.join(@module_path, file)
      assert File.exist?(file_path), "Required file should exist: #{file}"
    end
  end

  def test_ruby_files_have_valid_syntax
    ruby_files = Dir.glob(File.join(@module_path, '**', '*.rb'))
    
    ruby_files.each do |file|
      result = system("ruby -c #{file} 2>/dev/null")
      assert result, "Ruby file should have valid syntax: #{file}"
    end
  end

  def test_install_script_syntax
    install_script = File.join(@module_path, 'install.rb')
    result = system("ruby -c #{install_script} 2>/dev/null")
    assert result, "Install script should have valid Ruby syntax"
  end

  def test_version_file_content
    version_file = File.join(@module_path, 'VERSION')
    version = File.read(version_file).strip
    
    assert_match(/^\d+\.\d+\.\d+$/, version, "VERSION file should contain a valid semantic version")
  end

  def test_readme_contains_required_sections
    readme_file = File.join(@module_path, 'README.md')
    content = File.read(readme_file)
    
    required_sections = [
      '# Notifications Module',
      '## Features',
      '## Installation',
      '## Usage',
      '## Models',
      '## Configuration'
    ]
    
    required_sections.each do |section|
      assert content.include?(section), "README should contain section: #{section}"
    end
  end

  def test_notification_types_are_defined
    notification_model = File.join(@module_path, 'app/models/notification.rb')
    content = File.read(notification_model)
    
    assert content.include?('TYPES = '), "Notification model should define TYPES constant"
    assert content.include?('invitation_received'), "Should include invitation_received type"
    assert content.include?('billing_payment_failed'), "Should include billing_payment_failed type"
    assert content.include?('admin_alert'), "Should include admin_alert type"
  end

  def test_notification_service_has_convenience_methods
    service_file = File.join(@module_path, 'app/services/notification_service.rb')
    content = File.read(service_file)
    
    convenience_methods = [
      'def invitation_received',
      'def billing_payment_failed',
      'def job_completed',
      'def admin_alert'
    ]
    
    convenience_methods.each do |method|
      assert content.include?(method), "NotificationService should have convenience method: #{method}"
    end
  end

  def test_controllers_have_proper_actions
    notifications_controller = File.join(@module_path, 'app/controllers/notifications_controller.rb')
    content = File.read(notifications_controller)
    
    required_actions = ['index', 'show', 'read', 'dismiss', 'mark_all_read', 'dismiss_all']
    required_actions.each do |action|
      assert content.include?("def #{action}"), "NotificationsController should have #{action} action"
    end
  end

  def test_views_contain_proper_elements
    index_view = File.join(@module_path, 'app/views/notifications/index.html.erb')
    content = File.read(index_view)
    
    assert content.include?('data-controller="notifications"'), "Index view should have notifications controller"
    assert content.include?('notification-feed'), "Index view should have notification feed"
    
    preferences_view = File.join(@module_path, 'app/views/notification_preferences/show.html.erb')
    content = File.read(preferences_view)
    
    assert content.include?('form_with'), "Preferences view should have form"
    assert content.include?('email_notifications'), "Preferences view should have email notifications checkbox"
  end

  def test_javascript_controllers_are_stimulus_compatible
    notifications_js = File.join(@module_path, 'app/javascript/controllers/notifications_controller.js')
    content = File.read(notifications_js)
    
    assert content.include?('import { Controller } from "@hotwired/stimulus"'), "Should import Stimulus Controller"
    assert content.include?('export default class extends Controller'), "Should extend Controller class"
    assert content.include?('static values'), "Should define static values"
    
    toast_js = File.join(@module_path, 'app/javascript/controllers/notification_toast_controller.js')
    content = File.read(toast_js)
    
    assert content.include?('import { Controller } from "@hotwired/stimulus"'), "Should import Stimulus Controller"
    assert content.include?('dismiss()'), "Should have dismiss method"
  end

  def test_email_templates_exist
    html_template = File.join(@module_path, 'app/views/notification_mailer/notification_email.html.erb')
    text_template = File.join(@module_path, 'app/views/notification_mailer/notification_email.text.erb')
    
    assert File.exist?(html_template), "HTML email template should exist"
    assert File.exist?(text_template), "Text email template should exist"
    
    html_content = File.read(html_template)
    assert html_content.include?('<%= @notification.title %>'), "HTML template should include notification title"
    
    text_content = File.read(text_template)
    assert text_content.include?('<%= @notification.message %>'), "Text template should include notification message"
  end

  def test_test_files_exist
    test_files = [
      'test/models/notification_test.rb',
      'test/models/notification_preference_test.rb',
      'test/integration/notification_flow_test.rb',
      'test/services/notification_service_test.rb'
    ]
    
    test_files.each do |test_file|
      file_path = File.join(@module_path, test_file)
      assert File.exist?(file_path), "Test file should exist: #{test_file}"
    end
  end

  def test_configuration_defines_notification_types
    config_file = File.join(@module_path, 'config/initializers/notifications.rb')
    content = File.read(config_file)
    
    assert content.include?('config.notification_types'), "Config should define notification types"
    assert content.include?('invitation_received'), "Config should include invitation_received type"
    assert content.include?('default_channels'), "Config should define default channels"
  end
end

if __FILE__ == $0
  puts "🧪 Testing Notifications Module..."
  require 'test/unit'
  # Tests will run automatically when the file is executed
end