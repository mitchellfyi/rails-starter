# frozen_string_literal: true

# Button component for consistent styling across the application
class ButtonComponent < ApplicationComponent
  def initialize(
    variant: :primary,
    size: :medium,
    type: :button,
    disabled: false,
    loading: false,
    **html_options
  )
    @variant = variant
    @size = size
    @type = type
    @disabled = disabled || loading
    @loading = loading
    @html_options = html_options
  end

  private

  attr_reader :variant, :size, :type, :disabled, :loading, :html_options

  def button_classes
    [
      base_classes,
      variant_classes,
      size_classes,
      state_classes
    ].compact.join(' ')
  end

  def base_classes
    'inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed'
  end

  def variant_classes
    case variant
    when :primary
      'bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500'
    when :secondary
      'bg-gray-200 hover:bg-gray-300 text-gray-900 focus:ring-gray-500'
    when :danger
      'bg-red-600 hover:bg-red-700 text-white focus:ring-red-500'
    when :outline
      'border border-gray-300 hover:border-gray-400 bg-white text-gray-700 focus:ring-gray-500'
    when :ghost
      'text-gray-700 hover:bg-gray-100 focus:ring-gray-500'
    else
      'bg-gray-600 hover:bg-gray-700 text-white focus:ring-gray-500'
    end
  end

  def size_classes
    case size
    when :small
      'px-3 py-1.5 text-sm'
    when :medium
      'px-4 py-2 text-sm'
    when :large
      'px-6 py-3 text-base'
    else
      'px-4 py-2 text-sm'
    end
  end

  def state_classes
    'cursor-wait' if loading
  end

  def button_attributes
    html_options.merge(
      class: class_names(button_classes, html_options[:class]),
      type: type,
      disabled: disabled
    )
  end
end