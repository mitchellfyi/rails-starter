# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.
# Installs MCP (Multi-Context Provider) system with built-in fetchers.

say_status :synth_ai, "Installing AI module with MCP system"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai'
add_gem 'pgvector', '~> 0.5'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create AI configuration initializer
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.embedding_model = 'text-embedding-ada-002'
  RUBY

  # Copy MCP system files
  say_status :synth_ai, "Installing MCP (Multi-Context Provider) system"
  
  # Core MCP services
  copy_file 'app/services/mcp/registry.rb', 'app/services/mcp/registry.rb'
  copy_file 'app/services/mcp/context.rb', 'app/services/mcp/context.rb'
  
  # Base fetcher class
  copy_file 'app/services/mcp/fetcher/base.rb', 'app/services/mcp/fetcher/base.rb'
  
  # Built-in fetchers
  copy_file 'app/services/mcp/fetcher/database.rb', 'app/services/mcp/fetcher/database.rb'
  copy_file 'app/services/mcp/fetcher/http.rb', 'app/services/mcp/fetcher/http.rb'
  copy_file 'app/services/mcp/fetcher/file.rb', 'app/services/mcp/fetcher/file.rb'
  copy_file 'app/services/mcp/fetcher/semantic_memory.rb', 'app/services/mcp/fetcher/semantic_memory.rb'
  copy_file 'app/services/mcp/fetcher/code.rb', 'app/services/mcp/fetcher/code.rb'
  
  # MCP initializer
  copy_file 'config/initializers/mcp.rb', 'config/initializers/mcp.rb'
  
  # Vector embeddings model for semantic memory
  copy_file 'app/models/vector_embedding.rb', 'app/models/vector_embedding.rb'
  
  # Database migration for vector embeddings
  timestamp = Time.current.strftime('%Y%m%d%H%M%S')
  copy_file 'db/migrate/20241217000001_create_vector_embeddings.rb', 
            "db/migrate/#{timestamp}_create_vector_embeddings.rb"
  
  # Copy test files if using RSpec
  if File.exist?('spec/rails_helper.rb')
    say_status :synth_ai, "Installing MCP test files"
    
    copy_file 'spec/services/mcp/registry_spec.rb', 'spec/services/mcp/registry_spec.rb'
    copy_file 'spec/services/mcp/context_spec.rb', 'spec/services/mcp/context_spec.rb'
    copy_file 'spec/services/mcp/fetcher/database_spec.rb', 'spec/services/mcp/fetcher/database_spec.rb'
  end

  say_status :synth_ai, "MCP system installed successfully"
  say_status :synth_ai, "Run 'rails db:migrate' to create vector embeddings table"
  say_status :synth_ai, "Configure your OpenAI API key in credentials or environment variables"
  say_status :synth_ai, ""
  say_status :synth_ai, "Example usage:"
  say_status :synth_ai, "  context = Mcp::Context.new(user: current_user)"
  say_status :synth_ai, "  context.fetch(:recent_orders, model: 'Order', scope: :recent, limit: 5)"
  say_status :synth_ai, "  context.fetch(:github_repo, url: 'https://api.github.com/repos/rails/rails')"
  say_status :synth_ai, "  prompt_data = context.to_h"
end
