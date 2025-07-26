# frozen_string_literal: true

# MCP (Multi-Context Provider) initializer
# Registers built-in fetchers and configures the MCP system

Rails.application.config.after_initialize do
  # Register built-in fetchers
  
  # Database fetcher for ActiveRecord queries
  Mcp::Registry.register(:database, Mcp::Fetcher::Database)
  Mcp::Registry.register(:recent_orders, Mcp::Fetcher::RecentOrders)
  Mcp::Registry.register(:user_activity, Mcp::Fetcher::Database)
  
  # HTTP fetcher for external APIs
  Mcp::Registry.register(:http, Mcp::Fetcher::Http)
  Mcp::Registry.register(:github_repo, Mcp::Fetcher::Http)
  Mcp::Registry.register(:github_info, Mcp::Fetcher::GitHubInfo)
  Mcp::Registry.register(:slack_messages, Mcp::Fetcher::Http)
  
  # File fetcher for document parsing
  Mcp::Registry.register(:file, Mcp::Fetcher::File)
  Mcp::Registry.register(:parse_document, Mcp::Fetcher::File)
  Mcp::Registry.register(:document_summary, Mcp::Fetcher::DocumentSummary)
  Mcp::Registry.register(:extract_text, Mcp::Fetcher::File)
  
  # Semantic memory fetcher for embeddings
  Mcp::Registry.register(:semantic_memory, Mcp::Fetcher::SemanticMemory)
  Mcp::Registry.register(:semantic_search, Mcp::Fetcher::SemanticMemory)
  Mcp::Registry.register(:find_similar, Mcp::Fetcher::SemanticMemory)
  
  # Code fetcher for codebase introspection
  Mcp::Registry.register(:code, Mcp::Fetcher::Code)
  Mcp::Registry.register(:find_methods, Mcp::Fetcher::Code)
  Mcp::Registry.register(:search_code, Mcp::Fetcher::Code)

  Rails.logger.info "MCP: Registered #{Mcp::Registry.keys.size} built-in fetchers: #{Mcp::Registry.keys.join(', ')}"
end