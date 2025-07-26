# frozen_string_literal: true

class WorkspaceFeatureFlag < ApplicationRecord
  belongs_to :workspace
  belongs_to :feature_flag
  
  validates :workspace_id, uniqueness: { scope: :feature_flag_id }
end