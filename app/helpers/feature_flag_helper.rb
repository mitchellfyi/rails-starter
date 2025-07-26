# frozen_string_literal: true

module FeatureFlagHelper
  def feature_enabled?(flag_name, workspace = nil)
    return false unless defined?(FeatureFlag)
    
    flag = FeatureFlag.find_by(name: flag_name.to_s)
    return false unless flag
    
    workspace ||= current_workspace if respond_to?(:current_workspace)
    flag.enabled_for_workspace?(workspace)
  end
  
  def feature_disabled?(flag_name, workspace = nil)
    !feature_enabled?(flag_name, workspace)
  end
end

# Include in ApplicationController and ApplicationHelper when they exist
if defined?(ApplicationController)
  ApplicationController.include FeatureFlagHelper
end

if defined?(ApplicationHelper)
  ApplicationHelper.include FeatureFlagHelper
end