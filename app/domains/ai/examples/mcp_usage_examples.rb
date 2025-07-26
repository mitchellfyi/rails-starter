# frozen_string_literal: true

# Example usage of the MCP (Multi-Context Provider) system
# This file demonstrates how to use MCP to enrich AI prompts with dynamic data

class McpUsageExample
  # Example 1: Basic context fetching
  def self.basic_example(user, workspace)
    # Create context with base data
    context = Mcp::Context.new(user: user, workspace: workspace)
    
    # Fetch recent orders for this user
    context.fetch(:recent_orders,
      model: 'Order',
      scope: :recent,
      scope_args: [1.week.ago],
      limit: 5
    )
    
    # Fetch user's GitHub repositories
    context.fetch(:github_repos,
      url: "https://api.github.com/users/#{user.github_username}/repos",
      cache_key: "github_repos_#{user.id}",
      cache_ttl: 30.minutes
    )
    
    # Get all context data for prompt
    prompt_data = context.to_h
    
    # Use in AI prompt
    prompt = build_prompt(prompt_data)
    
    # Return both context and prompt
    {
      context: prompt_data,
      prompt: prompt,
      errors: context.errors
    }
  end

  # Example 2: Error handling and fallbacks
  def self.error_handling_example(user)
    context = Mcp::Context.new(user: user)
    
    # This might fail due to API limits
    context.fetch(:external_api_data,
      url: 'https://api.external-service.com/data',
      rate_limit_key: 'external_service',
      timeout: 5
    )
    
    # Check for errors and handle gracefully
    if context.error?(:external_api_data)
      Rails.logger.warn("External API failed: #{context.error_message(:external_api_data)}")
      
      # Try alternative data source
      context.fetch(:cached_data,
        model: 'CachedApiData',
        conditions: { user: user },
        order: 'updated_at DESC',
        limit: 1
      )
    end
    
    context.to_h
  end

  # Example 3: Semantic search for relevant documentation
  def self.semantic_search_example(user_query)
    context = Mcp::Context.new(query: user_query)
    
    # Find relevant documentation
    context.fetch(:relevant_docs,
      query: user_query,
      threshold: 0.75,
      limit: 3,
      namespace: 'documentation',
      content_types: ['tutorial', 'reference']
    )
    
    # Find similar code examples
    context.fetch(:code_examples,
      search_term: extract_keywords(user_query),
      search_type: :method_content,
      include_comments: true,
      max_results: 5
    )
    
    context.to_h
  end

  # Example 4: File processing and analysis
  def self.file_analysis_example(uploaded_file, user)
    context = Mcp::Context.new(user: user, file: uploaded_file)
    
    # Parse uploaded document
    context.fetch(:document_analysis,
      file_content: uploaded_file.read,
      file_type: uploaded_file.content_type,
      chunk_size: 1000,
      create_embeddings: true,
      extract_metadata: true
    )
    
    # Find similar existing documents
    if context.success?(:document_analysis)
      document_chunks = context[:document_analysis][:chunks]
      if document_chunks.any?
        # Use first chunk for similarity search
        first_chunk_text = document_chunks.first[:text]
        
        context.fetch(:similar_documents,
          query: first_chunk_text,
          limit: 5,
          threshold: 0.7,
          namespace: 'documents'
        )
      end
    end
    
    context.to_h
  end

  # Example 5: Multi-source data enrichment for customer support
  def self.customer_support_example(customer, issue_description)
    context = Mcp::Context.new(customer: customer, issue: issue_description)
    
    # Get customer's recent activity
    context.fetch(:customer_activity,
      model: 'CustomerActivity',
      conditions: { customer: customer },
      order: 'created_at DESC',
      limit: 10
    )
    
    # Get recent support tickets
    context.fetch(:recent_tickets,
      model: 'SupportTicket',
      conditions: { customer: customer, status: ['open', 'in_progress'] },
      limit: 5
    )
    
    # Search knowledge base for similar issues
    context.fetch(:knowledge_base,
      query: issue_description,
      threshold: 0.8,
      namespace: 'support_kb',
      limit: 3
    )
    
    # Get billing information if relevant
    if issue_description.include?('billing') || issue_description.include?('payment')
      context.fetch(:billing_info,
        model: 'BillingAccount',
        conditions: { customer: customer },
        limit: 1
      )
    end
    
    # Generate support prompt
    support_data = context.to_h
    prompt = build_support_prompt(support_data)
    
    {
      context: support_data,
      prompt: prompt,
      recommendations: generate_recommendations(support_data)
    }
  end

  # Example 6: Custom fetcher registration and usage
  def self.custom_fetcher_example
    # Define a custom weather fetcher
    weather_fetcher = Class.new(Mcp::Fetcher::Base) do
      def self.allowed_params
        [:location, :units]
      end

      def self.required_param?(param)
        param == :location
      end

      def self.fetch(location:, units: 'metric', **)
        # Mock weather API call
        {
          location: location,
          temperature: rand(15..30),
          condition: ['sunny', 'cloudy', 'rainy'].sample,
          units: units,
          fetched_at: Time.current
        }
      end

      def self.fallback_data(location: nil, **)
        {
          location: location,
          temperature: nil,
          condition: 'unknown',
          error: 'Weather service unavailable'
        }
      end

      def self.description
        "Fetches current weather conditions"
      end
    end

    # Register the custom fetcher
    Mcp::Registry.register(:weather, weather_fetcher)

    # Use the custom fetcher
    context = Mcp::Context.new
    context.fetch(:weather, location: 'San Francisco', units: 'imperial')
    
    context.to_h
  end

  private

  def self.build_prompt(data)
    <<~PROMPT
      Context Data:
      - User: #{data[:user]&.name}
      - Workspace: #{data[:workspace]&.name}
      - Recent Orders: #{data[:recent_orders]&.dig(:count) || 0} orders
      - GitHub Repos: #{data[:github_repos]&.dig(:data)&.size || 0} repositories
      
      Please provide assistance based on this context.
    PROMPT
  end

  def self.build_support_prompt(data)
    customer = data[:customer]
    issue = data[:issue]
    
    <<~PROMPT
      Customer Support Context:
      
      Customer: #{customer&.name} (ID: #{customer&.id})
      Issue: #{issue}
      
      Recent Activity: #{data[:customer_activity]&.dig(:count) || 0} activities
      Open Tickets: #{data[:recent_tickets]&.dig(:count) || 0} tickets
      KB Articles: #{data[:knowledge_base]&.dig(:results_count) || 0} relevant articles
      
      Based on this context, please provide a helpful response to the customer.
    PROMPT
  end

  def self.extract_keywords(text)
    # Simple keyword extraction (in real implementation, use NLP library)
    text.downcase.scan(/\w+/).select { |word| word.length > 3 }.uniq.first(5).join(' ')
  end

  def self.generate_recommendations(data)
    recommendations = []
    
    if data[:recent_tickets]&.dig(:count).to_i > 3
      recommendations << "Customer has multiple open tickets - consider priority escalation"
    end
    
    if data[:knowledge_base]&.dig(:results_count).to_i > 0
      recommendations << "Relevant knowledge base articles found - consider sharing with customer"
    end
    
    recommendations
  end
end