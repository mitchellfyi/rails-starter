# frozen_string_literal: true

# TestWithHyphen represents a test-with-hyphens item in the system
class TestWithHyphenItem < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Add any custom methods here
  def display_name
    name.presence || "Untitled TestWithHyphens"
  end

  def to_s
    display_name
  end
end
