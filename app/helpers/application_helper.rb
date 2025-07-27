# frozen_string_literal: true

# Application helper with component helpers and utility methods
module ApplicationHelper
  # Component helper methods for easier usage in views
  
  def render_button(text = nil, variant: :primary, **options, &block)
    content = block_given? ? capture(&block) : text
    render ButtonComponent.new(variant: variant, **options) do
      content
    end
  end
  
  def render_card(padding: :default, **options, &block)
    render CardComponent.new(padding: padding, **options) do
      capture(&block)
    end
  end
  
  def render_alert(message = nil, variant: :info, **options, &block)
    content = block_given? ? capture(&block) : message
    render AlertComponent.new(variant: variant, **options) do
      content
    end
  end
  
  # Flash message helper with proper styling
  def render_flash_messages
    return unless flash.any?
    
    content_tag :div, class: 'space-y-4 mb-6' do
      flash.map do |type, message|
        variant = case type.to_sym
                  when :notice, :success
                    :success
                  when :alert, :error
                    :error
                  when :warning
                    :warning
                  else
                    :info
                  end
        
        render_alert(message, variant: variant, dismissible: true, 
                    data: { controller: 'alert', auto_dismiss: 5 })
      end.join.html_safe
    end
  end
  
  # Page title helpers
  def page_title(title = nil)
    if title.present?
      content_for :title, title
      content_for :page_title, title
    end
    content_for?(:title) ? content_for(:title) : Rails.application.class.module_parent_name
  end
  
  def full_title(page_title = nil)
    base_title = Rails.application.class.module_parent_name
    if page_title.present?
      "#{page_title} | #{base_title}"
    else
      base_title
    end
  end
  
  # Icon helper for consistent icon usage
  def heroicon(name, variant: :outline, classes: 'w-5 h-5')
    # This would integrate with a heroicons gem or custom icon set
    # For now, return a placeholder
    content_tag :svg, class: "heroicon-#{name} #{classes}", 
                fill: variant == :solid ? 'currentColor' : 'none',
                stroke: variant == :outline ? 'currentColor' : 'none',
                viewBox: '0 0 24 24' do
      # Icon paths would go here - this is a simplified version
      content_tag :path, '', stroke_linecap: 'round', stroke_linejoin: 'round', stroke_width: '2'
    end
  end
  
  # Loading state helper
  def loading_state(loading = false, text = 'Loading...')
    return unless loading
    
    content_tag :div, class: 'flex items-center justify-center p-4' do
      concat content_tag(:div, '', class: 'animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2')
      concat content_tag(:span, text, class: 'text-gray-600')
    end
  end
  
  # Responsive navigation helper
  def mobile_menu_button
    content_tag :button, type: 'button', 
                class: 'md:hidden inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500',
                'aria-expanded': 'false',
                data: { controller: 'mobile-menu', action: 'click->mobile-menu#toggle' } do
      concat content_tag(:span, 'Open main menu', class: 'sr-only')
      concat heroicon('menu', classes: 'w-6 h-6')
    end
  end
  
  # Breadcrumb helper
  def render_breadcrumbs(items = [])
    return unless items.any?
    
    content_tag :nav, class: 'flex mb-6', 'aria-label': 'Breadcrumb' do
      content_tag :ol, class: 'flex items-center space-x-2' do
        items.map.with_index do |item, index|
          is_last = index == items.length - 1
          
          content_tag :li, class: 'flex items-center' do
            if index > 0
              concat heroicon('chevron-right', classes: 'w-4 h-4 text-gray-400 mr-2')
            end
            
            if is_last
              content_tag :span, item[:name], class: 'text-gray-500 font-medium'
            else
              link_to item[:name], item[:path], class: 'text-blue-600 hover:text-blue-800 font-medium'
            end
          end
        end.join.html_safe
      end
    end
  end
end