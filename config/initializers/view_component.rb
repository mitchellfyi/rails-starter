# frozen_string_literal: true

# ViewComponent configuration for component-based UI development
# Provides reusable, testable UI components

if defined?(ViewComponent)
  ViewComponent::Base.configure do |config|
    # Use Tailwind CSS classes for styling
    config.default_preview_layout = 'component_preview'
    
    # Enable preview functionality in development
    config.preview_controller = 'ComponentPreviewController' if Rails.env.development?
    
    # Configure component path
    config.preview_paths << Rails.root.join('spec/components/previews') if Rails.env.development?
    
    # Enable instrumentation for performance monitoring
    config.instrumentation_enabled = true
    
    # Configure view component generator
    config.generate_sidecar = true
    config.generate_stimulus_controller = true
    config.generate_preview = true if Rails.env.development?
  end
  
  Rails.logger.info '🧩 ViewComponent configured for component-based UI'
end

# Base component class with common functionality
class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include ViewComponent::Translatable if defined?(ViewComponent::Translatable)
  
  # Common CSS classes for consistent styling
  BUTTON_CLASSES = {
    primary: 'bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md transition duration-150 ease-in-out',
    secondary: 'bg-gray-200 hover:bg-gray-300 text-gray-900 font-medium py-2 px-4 rounded-md transition duration-150 ease-in-out',
    danger: 'bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-md transition duration-150 ease-in-out',
    outline: 'border border-gray-300 hover:border-gray-400 text-gray-700 font-medium py-2 px-4 rounded-md transition duration-150 ease-in-out'
  }.freeze
  
  CARD_CLASSES = 'bg-white shadow rounded-lg p-6 border border-gray-200'.freeze
  ALERT_CLASSES = {
    success: 'bg-green-50 border border-green-200 text-green-800 rounded-md p-4',
    error: 'bg-red-50 border border-red-200 text-red-800 rounded-md p-4',
    warning: 'bg-yellow-50 border border-yellow-200 text-yellow-800 rounded-md p-4',
    info: 'bg-blue-50 border border-blue-200 text-blue-800 rounded-md p-4'
  }.freeze
  
  private
  
  # Helper method to build CSS classes conditionally
  def class_names(*args)
    args.compact.join(' ')
  end
  
  # Helper method to apply variant classes
  def variant_class(base_classes, variant, custom_classes = nil)
    [base_classes[variant], custom_classes].compact.join(' ')
  end
end