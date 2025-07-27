# frozen_string_literal: true

class HomeController < ApplicationController
  before_action :set_documentation_sections, only: [:index, :docs]

  def index
    @hero_content = load_markdown_content('README.md')
    @featured_modules = featured_modules_content
  end

  def docs
    @doc_path = params[:doc_path] || 'README'
    @doc_content = load_documentation(@doc_path)
    @sidebar_sections = documentation_sidebar_sections
  end

  private

  def set_documentation_sections
    @doc_sections = [
      { 
        title: 'Getting Started', 
        items: [
          { name: 'Overview', path: 'README', file: 'README.md' },
          { name: 'Setup Guide', path: 'setup', file: 'docs/README.md' },
          { name: 'Configuration', path: 'configuration', file: 'docs/CONFIGURATION.md' },
          { name: 'Testing', path: 'testing', file: 'docs/TESTING.md' },
          { name: 'RailsPlan CLI', path: 'railsplan-cli', file: 'docs/railsplan_cli.md' },
          { name: 'Bootstrap CLI', path: 'bootstrap-cli', file: 'docs/modules/BOOTSTRAP_CLI.md' }
        ]
      },
      {
        title: 'Project Documentation',
        items: [
          { name: 'Changelog', path: 'changelog', file: 'CHANGELOG.md' },
          { name: 'Contributing Guide', path: 'contributing', file: 'CONTRIBUTING.md' },
          { name: 'Support', path: 'support', file: 'docs/SUPPORT.md' },
          { name: 'Module Upgrade Guide', path: 'module-upgrade-guide', file: 'docs/MODULE_UPGRADE_GUIDE.md' },
          { name: 'Contributing to Modules', path: 'contributing-modules', file: 'docs/CONTRIBUTING_MODULES.md' },
          { name: 'UI Module Management', path: 'ui-module-management', file: 'docs/ui_module_management_example.md' },
          { name: 'GitHub Actions Test Matrix', path: 'github-actions-test-matrix', file: 'docs/github-actions-test-matrix.md' }
        ]
      },
      {
        title: 'Architecture & Components',
        items: [
          { name: 'Domain Architecture', path: 'domain-architecture', file: 'docs/DOMAIN_ARCHITECTURE.md' },
          { name: 'Responsive Design', path: 'responsive-design', file: 'docs/RESPONSIVE_DESIGN.md' },
          { name: 'Components', path: 'components', file: 'docs/COMPONENTS.md' },
          { name: 'API Client Stubs', path: 'api-client-stubs', file: 'docs/API_CLIENT_STUBS.md' },
          { name: 'API Stubs Quick Reference', path: 'api-stubs-quick-ref', file: 'docs/API_STUBS_QUICK_REF.md' },
          { name: 'Paranoid Mode', path: 'paranoid-mode', file: 'docs/PARANOID_MODE.md' },
          { name: 'Rails Version Strategy', path: 'rails-version-strategy', file: 'docs/RAILS_VERSION_STRATEGY.md' }
        ]
      },
      {
        title: 'Development & Contributing',
        items: [
          { name: 'Development Setup', path: 'development-setup', file: 'CONTRIBUTING.md#development-setup' },
          { name: 'Gem Development', path: 'gem-development', file: 'CONTRIBUTING.md#gem-development' },
          { name: 'Testing Guidelines', path: 'testing-guidelines', file: 'CONTRIBUTING.md#testing' },
          { name: 'Code Style', path: 'code-style', file: 'CONTRIBUTING.md#code-style' },
          { name: 'Areas That Need Help', path: 'areas-need-help', file: 'CONTRIBUTING.md#areas-that-need-help' }
        ]
      },
      {
        title: 'Core Modules',
        items: [
          { name: 'AI Module', path: 'ai-module', file: 'docs/modules/ai.md' },
          { name: 'AI Multitenant Module', path: 'ai-multitenant-module', file: 'docs/modules/ai-multitenant.md' },
          { name: 'Admin Module', path: 'admin-module', file: 'docs/modules/admin.md' },
          { name: 'API Module', path: 'api-module', file: 'docs/modules/api.md' },
          { name: 'Auth Module', path: 'auth-module', file: 'docs/modules/auth.md' },
          { name: 'Billing Module', path: 'billing-module', file: 'docs/modules/billing.md' },
          { name: 'CMS Module', path: 'cms-module', file: 'docs/modules/cms.md' },
          { name: 'Deploy Module', path: 'deploy-module', file: 'docs/modules/deploy.md' },
          { name: 'Docs Module', path: 'docs-module', file: 'docs/modules/docs.md' },
          { name: 'MCP Module', path: 'mcp-module', file: 'docs/modules/mcp.md' },
          { name: 'Theme Module', path: 'theme-module', file: 'docs/modules/theme.md' }
        ]
      },
      {
        title: 'Additional Modules',
        items: [
          { name: 'Demo Feature Module', path: 'demo-feature-module', file: 'docs/modules/demo_feature.md' },
          { name: 'Flowbite Module', path: 'flowbite-module', file: 'docs/modules/flowbite.md' },
          { name: 'I18n Module', path: 'i18n-module', file: 'docs/modules/i18n.md' },
          { name: 'Notifications Module', path: 'notifications-module', file: 'docs/modules/notifications.md' },
          { name: 'Onboarding Module', path: 'onboarding-module', file: 'docs/modules/onboarding.md' },
          { name: 'Test Feature Module', path: 'test-feature-module', file: 'docs/modules/test_feature.md' },
          { name: 'Testing Module', path: 'testing-module', file: 'docs/modules/testing.md' },
          { name: 'User Settings Module', path: 'user-settings-module', file: 'docs/modules/user_settings.md' },
          { name: 'Workspace Module', path: 'workspace-module', file: 'docs/modules/workspace.md' }
        ]
      },
      {
        title: 'Implementation Guides',
        items: [
          { name: 'Agent Implementation', path: 'agent-implementation', file: 'docs/implementation/AGENT_IMPLEMENTATION_SUMMARY.md' },
          { name: 'AI Usage Estimator', path: 'ai-usage-estimator', file: 'docs/implementation/AI_USAGE_ESTIMATOR_SUMMARY.md' },
          { name: 'MCP Workspace', path: 'mcp-workspace', file: 'docs/implementation/MCP_WORKSPACE_IMPLEMENTATION.md' },
          { name: 'System Prompts', path: 'system-prompts', file: 'docs/modules/SYSTEM_PROMPTS.md' },
          { name: 'Token Usage Tracking', path: 'token-usage', file: 'docs/implementation/TOKEN_USAGE_TRACKING.md' },
          { name: 'Seeds Guide', path: 'seeds-guide', file: 'docs/modules/SEEDS.md' },
          { name: 'I18n Seeds', path: 'i18n-seeds', file: 'docs/modules/I18N_SEEDS.md' }
        ]
      }
    ]
  end

  def load_markdown_content(file_path)
    full_path = Rails.root.join(file_path)
    return nil unless File.exist?(full_path)

    content = File.read(full_path)
    # Extract title and description from markdown
    {
      content: content,
      title: extract_title(content),
      description: extract_description(content)
    }
  end

  def load_documentation(doc_path)
    # Find the file path for the given doc_path
    section_item = nil
    @doc_sections.each do |section|
      section_item = section[:items].find { |item| item[:path] == doc_path }
      break if section_item
    end

    return nil unless section_item

    file_path = Rails.root.join(section_item[:file])
    return nil unless File.exist?(file_path)

    content = File.read(file_path)
    {
      content: content,
      title: section_item[:name],
      file_path: section_item[:file],
      raw_content: content
    }
  end

  def featured_modules_content
    [
      {
        name: 'AI Module',
        description: 'First-class AI integration with versioned prompt templates, variable interpolation, and LLM job system.',
        path: 'ai-module',
        icon: 'ai'
      },
      {
        name: 'Admin Module',
        description: 'Comprehensive admin panel with audit logs, feature flags, and advanced administrative features.',
        path: 'admin-module', 
        icon: 'admin'
      },
      {
        name: 'Billing Module',
        description: 'Complete subscription and payment processing with Stripe integration and invoice generation.',
        path: 'billing-module',
        icon: 'billing'
      },
      {
        name: 'API Module',
        description: 'JSON:API compliant endpoints with automatic OpenAPI schema generation and comprehensive testing.',
        path: 'api-module',
        icon: 'api'
      },
      {
        name: 'CMS Module',
        description: 'Content management system with rich text editing, image uploads, and flexible content modeling.',
        path: 'cms-module',
        icon: 'cms'
      },
      {
        name: 'Workspace Module',
        description: 'Multi-tenant workspace management with user isolation and workspace-specific features.',
        path: 'workspace-module',
        icon: 'workspace'
      }
    ]
  end

  def documentation_sidebar_sections
    @doc_sections
  end

  def extract_title(content)
    lines = content.split("\n")
    title_line = lines.find { |line| line.start_with?('# ') }
    return 'Documentation' unless title_line
    
    title_line.gsub(/^# /, '').strip
  end

  def extract_description(content)
    lines = content.split("\n")
    # Find first non-empty line after title that doesn't start with #
    title_found = false
    lines.each do |line|
      if line.start_with?('# ')
        title_found = true
        next
      end
      
      if title_found && !line.strip.empty? && !line.start_with?('#')
        return line.strip
      end
    end
    
    'Rails SaaS Starter Template - A comprehensive template for building AI-native SaaS applications.'
  end
end