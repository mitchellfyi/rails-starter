# frozen_string_literal: true

# Modal component for overlays and dialogs
class ModalComponent < ApplicationComponent
  def initialize(
    id:,
    title: nil,
    size: :medium,
    closable: true,
    **html_options
  )
    @id = id
    @title = title
    @size = size
    @closable = closable
    @html_options = html_options
  end

  private

  attr_reader :id, :title, :size, :closable, :html_options

  def backdrop_classes
    'fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full'
  end

  def modal_classes
    [
      'relative top-20 mx-auto p-5 border w-11/12 shadow-lg rounded-md bg-white',
      size_classes
    ].join(' ')
  end

  def size_classes
    case size
    when :small
      'max-w-md'
    when :medium
      'max-w-lg'
    when :large
      'max-w-2xl'
    when :xl
      'max-w-4xl'
    else
      'max-w-lg'
    end
  end

  def header_classes
    'flex items-center justify-between pb-3'
  end

  def title_classes
    'text-lg font-medium text-gray-900'
  end

  def close_button_classes
    'text-gray-400 hover:text-gray-600 transition-colors'
  end

  def close_button_svg
    '<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
    </svg>'.html_safe
  end
end