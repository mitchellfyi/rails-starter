# frozen_string_literal: true

class OnboardingStepHandler
  attr_reader :user, :detector

  def initialize(user)
    @user = user
    @detector = ModuleDetector.new
  end

  def handle_step(step, params = {})
    case step.to_s
    when 'welcome'
      handle_welcome
    when 'create_workspace'
      handle_create_workspace(params)
    when 'invite_colleagues'
      handle_invite_colleagues(params)
    when 'connect_billing'
      handle_connect_billing(params)
    when 'connect_ai'
      handle_connect_ai(params)
    when 'explore_features'
      handle_explore_features
    else
      false
    end
  end

  def step_available?(step)
    case step.to_s
    when 'welcome', 'explore_features'
      true
    when 'create_workspace', 'invite_colleagues'
      detector.workspace_module_available?
    when 'connect_billing'
      detector.billing_module_available?
    when 'connect_ai'
      detector.ai_module_available?
    else
      false
    end
  end

  def get_step_data(step)
    case step.to_s
    when 'welcome'
      welcome_step_data
    when 'create_workspace'
      create_workspace_step_data
    when 'invite_colleagues'
      invite_colleagues_step_data
    when 'connect_billing'
      connect_billing_step_data
    when 'connect_ai'
      connect_ai_step_data
    when 'explore_features'
      explore_features_step_data
    when 'complete'
      complete_step_data
    else
      {}
    end
  end

  private

  def handle_welcome
    mark_step_complete('welcome')
    true
  end

  def handle_create_workspace(params)
    return false unless detector.workspace_module_available?

    if params[:workspace].present?
      # Create workspace if parameters provided
      workspace = user.created_workspaces.build(
        name: params[:workspace][:name],
        description: params[:workspace][:description]
      )
      
      if workspace.save
        mark_step_complete('create_workspace')
        return true
      else
        return false
      end
    end

    # If no params, just mark as viewed (user can skip or complete later)
    false
  end

  def handle_invite_colleagues(params)
    return false unless detector.workspace_module_available?

    if params[:invitations].present? && params[:workspace_id].present?
      workspace = user.created_workspaces.find_by(id: params[:workspace_id])
      return false unless workspace

      invitations_sent = 0
      params[:invitations].each do |invitation_params|
        next if invitation_params[:email].blank?

        invitation = workspace.invitations.build(
          email: invitation_params[:email],
          role: invitation_params[:role] || 'member',
          invited_by: user
        )

        if invitation.save
          # Send invitation email if mailer exists
          if defined?(InvitationMailer)
            InvitationMailer.invite_user(invitation).deliver_later
          end
          invitations_sent += 1
        end
      end

      if invitations_sent > 0
        mark_step_complete('invite_colleagues')
        return true
      end
    end

    # Mark as complete even if no invitations sent (user chose to skip)
    mark_step_complete('invite_colleagues')
    true
  end

  def handle_connect_billing(params)
    return false unless detector.billing_module_available?

    # For now, just mark as complete - actual billing setup would be more complex
    # This is where you'd integrate with Stripe setup flow
    mark_step_complete('connect_billing')
    true
  end

  def handle_connect_ai(params)
    return false unless detector.ai_module_available?

    # For now, just mark as complete - actual AI setup would be more complex  
    # This is where you'd configure AI provider settings
    mark_step_complete('connect_ai')
    true
  end

  def handle_explore_features
    mark_step_complete('explore_features')
    true
  end

  def mark_step_complete(step)
    user.start_onboarding! unless user.onboarding_progress
    user.onboarding_progress.mark_step_complete(step)
  end

  # Data for each step to help with view rendering
  def welcome_step_data
    {
      title: 'Welcome to Your New Application!',
      description: 'Let\'s get you set up with everything you need to get started.',
      available_modules: detector.available_modules,
      estimated_time: "#{detector.module_count + 2} minutes"
    }
  end

  def create_workspace_step_data
    {
      title: 'Create Your First Workspace',
      description: 'Workspaces help you organize your work and collaborate with your team.',
      existing_workspaces: user.created_workspaces.limit(5)
    }
  end

  def invite_colleagues_step_data
    {
      title: 'Invite Your Team',
      description: 'Get your colleagues on board to start collaborating.',
      available_workspaces: user.created_workspaces.limit(10)
    }
  end

  def connect_billing_step_data
    {
      title: 'Set Up Billing',
      description: 'Configure your payment method to unlock premium features.',
      has_billing: user.respond_to?(:subscriptions) && user.subscriptions.any?
    }
  end

  def connect_ai_step_data
    {
      title: 'Connect AI Providers',
      description: 'Set up AI integrations to supercharge your workflow.',
      has_ai_config: user.respond_to?(:llm_outputs) && user.llm_outputs.any?
    }
  end

  def explore_features_step_data
    {
      title: 'Explore Key Features',
      description: 'Take a quick tour of what you can do with your new application.',
      available_modules: detector.available_modules
    }
  end

  def complete_step_data
    {
      title: 'Setup Complete!',
      description: 'You\'re all set up and ready to start using your application.',
      completed_steps: user.onboarding_progress&.completed_steps || []
    }
  end
end