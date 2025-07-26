# Admin panel configuration and audit logging setup
Rails.application.config.to_prepare do
  # Enable automatic login tracking when Devise is available
  if defined?(Devise)
    Warden::Manager.after_set_user except: :fetch do |user, auth, opts|
      # Track user login in audit logs
      if user.respond_to?(:email) && defined?(AuditLog)
        AuditLog.log_login(
          user,
          ip_address: auth.request.remote_ip,
          user_agent: auth.request.user_agent
        )
      end
    end
  end
  
  # Configure audit logging for impersonation if available
  if defined?(ApplicationController)
    ApplicationController.class_eval do
      def log_admin_action(action, description, metadata = {})
        return unless current_user&.admin? && defined?(AuditLog)
        
        AuditLog.create_log(
          user: current_user,
          action: action,
          description: description,
          metadata: metadata,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
      end
    end
  end
end