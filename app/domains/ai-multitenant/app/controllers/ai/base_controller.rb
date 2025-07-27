# frozen_string_literal: true

class Ai::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_current_workspace
  before_action :check_ai_access

  private

  def ensure_current_workspace
    unless current_workspace
      redirect_to root_path, alert: "Please select a workspace to access AI features."
    end
  end

  def check_ai_access
    unless can_access_ai?
      redirect_to root_path, alert: "You don't have permission to access AI features in this workspace."
    end
  end

  def can_access_ai?
    # Check if user has permission to use AI in this workspace
    # This can be customized based on your authorization system
    current_workspace_user&.can_use_ai? || current_workspace_user&.admin?
  end

  def current_workspace_runner
    @current_workspace_runner ||= WorkspaceLLMJobRunner.new(current_workspace)
  end
end