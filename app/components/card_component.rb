# frozen_string_literal: true

# Card component for consistent content containers
class CardComponent < ApplicationComponent
  def initialize(
    padding: :default,
    shadow: :default,
    border: true,
    hover: false,
    **html_options
  )
    @padding = padding
    @shadow = shadow
    @border = border
    @hover = hover
    @html_options = html_options
  end

  private

  attr_reader :padding, :shadow, :border, :hover, :html_options

  def card_classes
    [
      base_classes,
      padding_classes,
      shadow_classes,
      border_classes,
      hover_classes
    ].compact.join(' ')
  end

  def base_classes
    'bg-white rounded-lg'
  end

  def padding_classes
    case padding
    when :none
      ''
    when :small
      'p-4'
    when :default
      'p-6'
    when :large
      'p-8'
    else
      'p-6'
    end
  end

  def shadow_classes
    case shadow
    when :none
      ''
    when :small
      'shadow-sm'
    when :default
      'shadow'
    when :large
      'shadow-lg'
    when :xl
      'shadow-xl'
    else
      'shadow'
    end
  end

  def border_classes
    border ? 'border border-gray-200' : ''
  end

  def hover_classes
    hover ? 'hover:shadow-lg transition-shadow duration-200' : ''
  end

  def card_attributes
    html_options.merge(
      class: class_names(card_classes, html_options[:class])
    )
  end
end