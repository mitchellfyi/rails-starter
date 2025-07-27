# frozen_string_literal: true

# Breadcrumb component for navigation
class BreadcrumbComponent < ApplicationComponent
  def initialize(items: [], **html_options)
    @items = items
    @html_options = html_options
  end

  private

  attr_reader :items, :html_options

  def has_items?
    items.any?
  end

  def breadcrumb_classes
    'flex items-center space-x-2 text-sm text-gray-500'
  end

  def separator_svg
    '<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
    </svg>'.html_safe
  end
end