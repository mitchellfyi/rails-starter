# frozen_string_literal: true

# Support model for tracking AI credential test results
class AiCredentialTest < ApplicationRecord
  belongs_to :ai_credential

  validates :tested_at, presence: true
  validates :successful, inclusion: { in: [true, false] }

  scope :successful, -> { where(successful: true) }
  scope :failed, -> { where(successful: false) }
  scope :recent, -> { where(tested_at: 24.hours.ago..) }

  def success?
    successful?
  end

  def failure?
    !successful?
  end
end