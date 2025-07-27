# frozen_string_literal: true

# Loading component for async operations and page states
class LoadingComponent < ApplicationComponent
  def initialize(
    variant: :spinner,
    size: :medium,
    text: nil,
    overlay: false,
    **html_options
  )
    @variant = variant
    @size = size
    @text = text
    @overlay = overlay
    @html_options = html_options
  end

  private

  attr_reader :variant, :size, :text, :overlay, :html_options

  def container_classes
    base_classes = ['flex items-center justify-center']
    base_classes << 'fixed inset-0 bg-white bg-opacity-75 z-50' if overlay
    base_classes << 'p-4' unless overlay
    base_classes.join(' ')
  end

  def spinner_classes
    [
      'animate-spin rounded-full border-b-2',
      size_classes,
      color_classes
    ].join(' ')
  end

  def size_classes
    case size
    when :small
      'h-4 w-4'
    when :medium
      'h-8 w-8'
    when :large
      'h-12 w-12'
    when :xl
      'h-16 w-16'
    else
      'h-8 w-8'
    end
  end

  def color_classes
    'border-blue-600'
  end

  def text_classes
    case size
    when :small
      'text-sm'
    when :medium
      'text-base'
    when :large
      'text-lg'
    when :xl
      'text-xl'
    else
      'text-base'
    end
  end

  def dots_animation
    '...'
  end

  def pulse_classes
    [
      'animate-pulse bg-gray-300 rounded',
      size_classes
    ].join(' ')
  end

  def skeleton_lines
    case size
    when :small
      2
    when :medium
      3
    when :large
      4
    when :xl
      5
    else
      3
    end
  end
end