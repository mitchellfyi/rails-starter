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
          { name: 'Testing', path: 'testing', file: 'docs/TESTING.md' }
        ]
      },
      {
        title: 'Architecture',
        items: [
          { name: 'Domain Architecture', path: 'domain-architecture', file: 'docs/DOMAIN_ARCHITECTURE.md' },
          { name: 'Responsive Design', path: 'responsive-design', file: 'docs/RESPONSIVE_DESIGN.md' }
        ]
      },
      {
        title: 'Modules',
        items: [
          { name: 'AI Module', path: 'ai-module', file: 'docs/modules/ai.md' },
          { name: 'Admin Module', path: 'admin-module', file: 'docs/modules/admin.md' },
          { name: 'API Module', path: 'api-module', file: 'docs/modules/api.md' },
          { name: 'Auth Module', path: 'auth-module', file: 'docs/modules/auth.md' },
          { name: 'Theme Module', path: 'theme-module', file: 'docs/modules/theme.md' },
          { name: 'MCP Module', path: 'mcp-module', file: 'docs/modules/mcp.md' },
          { name: 'Deploy Module', path: 'deploy-module', file: 'docs/modules/deploy.md' }
        ]
      },
      {
        title: 'Implementation Guides',
        items: [
          { name: 'Agent Implementation', path: 'agent-implementation', file: 'AGENT_IMPLEMENTATION_SUMMARY.md' },
          { name: 'AI Usage Estimator', path: 'ai-usage-estimator', file: 'AI_USAGE_ESTIMATOR_SUMMARY.md' },
          { name: 'MCP Workspace', path: 'mcp-workspace', file: 'MCP_WORKSPACE_IMPLEMENTATION.md' },
          { name: 'System Prompts', path: 'system-prompts', file: 'SYSTEM_PROMPTS.md' },
          { name: 'Token Usage Tracking', path: 'token-usage', file: 'TOKEN_USAGE_TRACKING.md' }
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
        name: 'Auth Module',
        description: 'Complete authentication system with user registration, OAuth integration, and security features.',
        path: 'auth-module',
        icon: 'auth'
      },
      {
        name: 'API Module',
        description: 'JSON:API compliant endpoints with automatic OpenAPI schema generation.',
        path: 'api-module',
        icon: 'api'
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