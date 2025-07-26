# frozen_string_literal: true

# Example usage of the MCP (Multi-Context Provider) system
# This file demonstrates how to use MCP to enrich AI prompts with dynamic data

class McpUsageExample
  # Example 1: Basic context fetching with new LLMJob integration
  def self.basic_llm_example(user, workspace)
    # Simple approach: Use LLMJob with MCP fetchers
    LLMJob.perform_later(
      template: "Hello {{user_name}}, you have {{count}} recent orders totaling ${{summary_total_value}}. How can I help you today?",
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :recent_orders,
          params: { limit: 5 }
        }
      ]
    )
  end

  # Example 2: Advanced multi-source context enrichment
  def self.customer_support_example(user, issue_description)
    # Template that uses multiple data sources
    support_template = <<~TEMPLATE
      Customer Support Analysis for {{user_name}}:
      
      RECENT ACTIVITY:
      - Orders: {{count}} recent orders ({{summary_statuses}})
      - Total Spent: ${{summary_total_value}}
      - Account Type: Premium Customer
      
      GITHUB PROFILE:
      {{#profile}}
      - Developer: {{profile_name}} ({{profile_public_repos}} repositories)
      - GitHub Activity: {{profile_followers}} followers
      {{/profile}}
      
      ISSUE DESCRIPTION:
      {{issue_description}}
      
      DOCUMENT CONTEXT:
      {{#summary}}
      Related Documentation: {{summary}}
      Key Topics: {{keywords}}
      {{/summary}}
      
      Please provide a comprehensive support response addressing the customer's technical level and purchase history.
    TEMPLATE

    # Configure multiple MCP fetchers
    mcp_fetchers = [
      {
        key: :recent_orders,
        params: { 
          limit: 10,
          include_details: true,
          since: 3.months.ago
        }
      }
    ]

    # Add GitHub info if available
    if user.github_username.present?
      mcp_fetchers << {
        key: :github_info,
        params: {
          username: user.github_username,
          github_token: Rails.application.credentials.github&.token,
          include_repos: true,
          repo_limit: 5
        }
      }
    end

    # Add relevant documentation
    if issue_description.include?('API') || issue_description.include?('integration')
      mcp_fetchers << {
        key: :document_summary,
        params: {
          file_path: Rails.root.join('docs', 'api_integration_guide.md'),
          max_summary_length: 300,
          extract_keywords: true
        }
      }
    end

    LLMJob.perform_later(
      template: support_template,
      model: 'gpt-4',
      context: { 
        user_name: user.name,
        issue_description: issue_description
      },
      user_id: user.id,
      mcp_fetchers: mcp_fetchers,
      format: 'markdown'
    )
  end

  # Example 3: Product recommendation system
  def self.product_recommendation_example(user)
    recommendation_template = <<~TEMPLATE
      Product Recommendation for {{user_name}}:
      
      PURCHASE HISTORY:
      {{#recent_orders}}
      - Recent Orders: {{count}} orders
      - Spending Pattern: ${{summary_average_value}} average order
      - Preferred Categories: {{summary_statuses}}
      {{/recent_orders}}
      
      TECHNICAL PROFILE:
      {{#github_profile}}
      - Programming Languages: {{repositories_summary_languages}}
      - Project Activity: {{repositories_count}} repositories
      - Experience Level: {{profile_followers}} GitHub followers
      {{/github_profile}}
      
      Generate personalized product recommendations based on technical interests and purchase history.
    TEMPLATE

    LLMJob.perform_later(
      template: recommendation_template,
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :recent_orders,
          params: {
            limit: 20,
            include_details: true,
            since: 6.months.ago
          }
        },
        {
          key: :github_info,
          params: {
            username: user.github_username,
            github_token: ENV['GITHUB_TOKEN'],
            include_repos: true,
            repo_limit: 10
          }
        }
      ]
    )
  end

  # Example 4: Document analysis workflow
  def self.document_analysis_example(uploaded_file, user)
    analysis_template = <<~TEMPLATE
      Document Analysis Report for {{user_name}}:
      
      DOCUMENT OVERVIEW:
      - File: {{file_path}}
      - Type: {{file_type}}
      - Size: {{content_length}} characters ({{word_count}} words)
      - Reading Time: {{metadata_reading_time_minutes}} minutes
      
      CONTENT SUMMARY:
      {{summary}}
      
      KEY TOPICS:
      {{keywords}}
      
      LANGUAGE & STRUCTURE:
      - Language: {{metadata_language}}
      - Paragraphs: {{metadata_paragraph_count}}
      - Sentences: {{metadata_sentence_count}}
      
      Please provide insights about this document's content, structure, and potential use cases.
    TEMPLATE

    LLMJob.perform_later(
      template: analysis_template,
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :document_summary,
          params: {
            file_content: uploaded_file.read,
            file_type: uploaded_file.content_type,
            max_summary_length: 500,
            extract_keywords: true,
            include_metadata: true,
            chunk_size: 1000
          }
        }
      ]
    )
  end

  # Example 5: Code review assistance
  def self.code_review_example(user, repository_name)
    code_review_template = <<~TEMPLATE
      Code Review Analysis for {{user_name}}:
      
      REPOSITORY CONTEXT:
      {{#repositories}}
      - Repository: {{repositories_repositories_0_name}}
      - Language: {{repositories_repositories_0_language}}
      - Stars: {{repositories_repositories_0_stars}}
      - Last Updated: {{repositories_repositories_0_updated_at}}
      {{/repositories}}
      
      DEVELOPER PROFILE:
      - GitHub: {{profile_name}}
      - Total Repositories: {{profile_public_repos}}
      - Community: {{profile_followers}} followers
      
      Please provide a code review focusing on best practices for {{repositories_repositories_0_language}} development.
    TEMPLATE

    LLMJob.perform_later(
      template: code_review_template,
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :github_info,
          params: {
            username: user.github_username,
            github_token: ENV['GITHUB_TOKEN'],
            include_repos: true,
            repo_limit: 1
          }
        }
      ]
    )
  end

  # Example 6: Real-time context with error handling
  def self.robust_context_example(user)
    context_template = <<~TEMPLATE
      Comprehensive User Context for {{user_name}}:
      
      {{#count}}
      RECENT ACTIVITY:
      Recent Orders: {{count}} orders
      {{/count}}
      
      {{#profile}}
      DEVELOPER PROFILE:
      GitHub: {{profile_name}}
      {{/profile}}
      
      {{#error_recent_orders}}
      Note: Order history temporarily unavailable
      {{/error_recent_orders}}
      
      {{#error_github_info}}
      Note: GitHub profile temporarily unavailable
      {{/error_github_info}}
      
      Please provide assistance based on available context.
    TEMPLATE

    LLMJob.perform_later(
      template: context_template,
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :recent_orders,
          params: { limit: 5 }
        },
        {
          key: :github_info,
          params: {
            username: user.github_username,
            github_token: ENV['GITHUB_TOKEN']
          }
        }
      ]
    )
  end

  # Example 7: Direct MCP Context usage (for more control)
  def self.direct_mcp_example(user, workspace)
    # Create context with base data
    context = Mcp::Context.new(user: user, workspace: workspace)
    
    # Fetch recent orders for this user
    context.fetch(:recent_orders,
      limit: 5,
      since: 1.week.ago,
      include_details: true
    )
    
    # Fetch user's GitHub repositories
    if user.github_username.present?
      context.fetch(:github_info,
        username: user.github_username,
        github_token: ENV['GITHUB_TOKEN'],
        include_repos: true,
        repo_limit: 10
      )
    end
    
    # Check for errors and handle gracefully
    if context.has_errors?
      Rails.logger.warn("MCP errors: #{context.error_keys.join(', ')}")
    end

    # Get all context data for prompt
    prompt_data = context.to_h
    
    # Use in AI prompt manually
    template = build_custom_prompt(prompt_data)
    
    LLMJob.perform_later(
      template: template,
      model: 'gpt-4',
      context: prompt_data,
      user_id: user.id
    )
  end

  # Example 8: Async processing with callbacks
  def self.async_processing_example(user, callback_url)
    job = LLMJob.perform_later(
      template: "Analyze user {{user_name}} with {{count}} recent orders",
      model: 'gpt-4',
      context: { user_name: user.name },
      user_id: user.id,
      mcp_fetchers: [
        {
          key: :recent_orders,
          params: { limit: 10 }
        }
      ]
    )

    # You could add webhook notification when job completes
    # WebhookJob.perform_later(callback_url, job.job_id)
    
    job
  end

  private

  def self.build_custom_prompt(data)
    <<~PROMPT
      Context Data:
      - User: #{data[:user]&.name}
      - Workspace: #{data[:workspace]&.name}
      - Recent Orders: #{data[:recent_orders]&.dig(:count) || 0} orders
      - GitHub Repos: #{data[:github_info]&.dig(:repositories, :count) || 0} repositories
      
      Please provide assistance based on this context.
    PROMPT
  end
end