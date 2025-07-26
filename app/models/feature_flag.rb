# frozen_string_literal: true

class FeatureFlag < ApplicationRecord
  has_many :workspace_feature_flags, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  
  scope :active, -> { where(enabled: true) }
  scope :inactive, -> { where(enabled: false) }
  
  def enabled_for_workspace?(workspace)
    return enabled unless workspace
    
    workspace_flag = workspace_feature_flags.find_by(workspace: workspace)
    workspace_flag ? workspace_flag.enabled : enabled
  end
  
  def workspace_override?(workspace)
    workspace_feature_flags.exists?(workspace: workspace)
  end
  
  def workspace_status(workspace)
    return 'Global' unless workspace
    
    workspace_flag = workspace_feature_flags.find_by(workspace: workspace)
    if workspace_flag
      workspace_flag.enabled? ? 'Enabled for Workspace' : 'Disabled for Workspace'
    else
      enabled? ? 'Inherited (Enabled)' : 'Inherited (Disabled)'
    end
  end
  
  def toggle_for_workspace!(workspace)
    workspace_flag = workspace_feature_flags.find_or_initialize_by(workspace: workspace)
    workspace_flag.enabled = !workspace_flag.enabled
    workspace_flag.save!
  end
end