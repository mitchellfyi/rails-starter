# frozen_string_literal: true

# TestFeature represents a test_feature item in the system
class TestFeatureItem < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Add any custom methods here
  def display_name
    name.presence || "Untitled TestFeature"
  end

  def to_s
    display_name
  end
end
