# frozen_string_literal: true

class ModuleDetector
  def workspace_module_available?
    defined?(Workspace) && Workspace < ApplicationRecord
  end

  def billing_module_available?
    defined?(Subscription) && Subscription < ApplicationRecord
  end

  def ai_module_available?
    defined?(LLMOutput) && LLMOutput < ApplicationRecord
  end

  def admin_module_available?
    defined?(AdminUser) && AdminUser < ApplicationRecord
  end

  def cms_module_available?
    defined?(Post) && Post < ApplicationRecord
  end

  def available_modules
    modules = []
    modules << 'workspace' if workspace_module_available?
    modules << 'billing' if billing_module_available?
    modules << 'ai' if ai_module_available?
    modules << 'admin' if admin_module_available?
    modules << 'cms' if cms_module_available?
    modules
  end

  def module_count
    available_modules.length
  end
end