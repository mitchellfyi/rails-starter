# frozen_string_literal: true

require 'test_helper'

class McpIntegrationTest < ActiveSupport::TestCase
  def setup
    @user = OpenStruct.new(id: 1, name: 'Test User', github_username: 'testuser')
    User.stubs(:find_by).with(id: 1).returns(@user)
    
    # Mock Rails.cache for tests
    Rails.stubs(:cache).returns(ActiveSupport::Cache::MemoryStore.new)
    
    # Mock Order model for recent orders
    @mock_order_class = Class.new do
      def self.all
        relation = OpenStruct.new(
          where: ->(conditions) { self },
          order: ->(order_by) { self },
          limit: ->(limit) { self },
          offset: ->(offset) { self },
          except: ->(args) { self },
          count: -> { 2 }
        )
        
        relation.define_singleton_method(:to_a) do
          [
            {
              'id' => 1,
              'user_id' => 1,
              'total' => 99.99,
              'status' => 'completed',
              'created_at' => 2.days.ago.to_s
            },
            {
              'id' => 2,
              'user_id' => 1,
              'total' => 149.50,
              'status' => 'pending',
              'created_at' => 1.day.ago.to_s
            }
          ]
        end
        
        relation
      end
      
      def self.column_names
        ['id', 'user_id', 'workspace_id', 'total', 'status', 'created_at']
      end
      
      def self.respond_to?(method)
        true
      end
    end
    
    String.any_instance.stubs(:constantize).returns(@mock_order_class)
  end

  test "LLMJob enriches context with recent orders" do
    template = <<~TEMPLATE
      Customer Analysis for {{user_name}}:
      
      Recent Orders:
      - Total Orders: {{count}}
      - Total Value: ${{summary_total_value}}
      - Average Order: ${{summary_average_value}}
      
      Please provide personalized recommendations.
    TEMPLATE

    mcp_fetchers = [
      {
        key: :recent_orders,
        params: { limit: 5 }
      }
    ]

    result = LLMJob.perform_now(
      template: template,
      model: "test-model",
      context: { user_name: "Test User" },
      user_id: 1,
      mcp_fetchers: mcp_fetchers
    )

    assert result.is_a?(LLMOutput)
    
    # Verify the context was enriched with order data
    assert result.context.key?('count')
    assert result.context.key?('summary')
    assert_equal 2, result.context['count']
    
    # Verify the prompt includes the enriched data
    assert_includes result.prompt, "Total Orders: 2"
    assert_includes result.prompt, "Total Value: $249.49"
    assert_includes result.prompt, "Average Order: $124.75"
  end

  test "LLMJob handles multiple MCP fetchers" do
    # Set up WebMock for GitHub API call
    require 'webmock/test_unit'
    WebMock.enable!
    
    github_response = {
      'name' => 'Test User',
      'public_repos' => 10,
      'followers' => 50
    }
    
    stub_request(:get, "https://api.github.com/users/testuser")
      .to_return(
        status: 200,
        body: github_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    template = <<~TEMPLATE
      User Profile for {{user_name}}:
      
      Recent Orders: {{count}} orders
      GitHub Profile: {{profile_name}} with {{profile_public_repos}} repositories
      
      Generate a comprehensive user analysis.
    TEMPLATE

    mcp_fetchers = [
      {
        key: :recent_orders,
        params: { limit: 3 }
      },
      {
        key: :github_info,
        params: { 
          username: 'testuser',
          include_repos: false
        }
      }
    ]

    result = LLMJob.perform_now(
      template: template,
      model: "test-model",
      context: { user_name: "Test User" },
      user_id: 1,
      mcp_fetchers: mcp_fetchers
    )

    assert result.is_a?(LLMOutput)
    
    # Verify both data sources were included
    assert result.context.key?('count') # from recent_orders
    assert result.context.key?('profile') # from github_info
    
    # Verify the prompt includes data from both fetchers
    assert_includes result.prompt, "2 orders"
    assert_includes result.prompt, "Test User with 10 repositories"
    
    WebMock.disable!
  end

  test "LLMJob continues with partial data when one fetcher fails" do
    # Mock failing GitHub fetcher
    failing_github_fetcher = Class.new do
      def self.fetch(**)
        raise StandardError, "GitHub API failed"
      end
    end
    
    Mcp::Registry.stubs(:get).with(:github_info).returns(failing_github_fetcher)

    template = <<~TEMPLATE
      User Analysis:
      Orders: {{count}} recent orders
      GitHub: {{profile_name}} (if available)
    TEMPLATE

    mcp_fetchers = [
      {
        key: :recent_orders,
        params: { limit: 5 }
      },
      {
        key: :github_info,
        params: { username: 'testuser' }
      }
    ]

    result = LLMJob.perform_now(
      template: template,
      model: "test-model",
      context: { user_name: "Test User" },
      user_id: 1,
      mcp_fetchers: mcp_fetchers
    )

    assert result.is_a?(LLMOutput)
    
    # Should have orders data but not GitHub data
    assert result.context.key?('count')
    assert_not result.context.key?('profile')
    
    # Verify successful fetcher data is still in the prompt
    assert_includes result.prompt, "2 recent orders"
  end

  test "LLMJob works with document summary fetcher" do
    # Create a temporary document
    doc_content = <<~DOC
      Product Requirements Document
      
      This document outlines the requirements for the new AI-powered
      customer service system. The system should integrate with existing
      CRM tools and provide intelligent responses to customer inquiries.
      
      Key features include natural language processing, sentiment analysis,
      and automated ticket routing based on urgency and topic classification.
    DOC
    
    temp_file = '/tmp/test_prd.txt'
    File.write(temp_file, doc_content)

    template = <<~TEMPLATE
      Context Analysis:
      Document Summary: {{summary}}
      Key Topics: {{keywords}}
      
      Based on this document, provide implementation recommendations.
    TEMPLATE

    mcp_fetchers = [
      {
        key: :document_summary,
        params: {
          file_path: temp_file,
          max_summary_length: 200,
          extract_keywords: true
        }
      }
    ]

    result = LLMJob.perform_now(
      template: template,
      model: "test-model",
      context: { user_name: "Product Manager" },
      mcp_fetchers: mcp_fetchers
    )

    assert result.is_a?(LLMOutput)
    
    # Verify document analysis data was included
    assert result.context.key?('summary')
    assert result.context.key?('keywords')
    
    # Verify the prompt includes document insights
    assert_includes result.prompt, "customer service system"
    assert result.context['keywords'].include?('system')
    
    File.delete(temp_file)
  end

  test "MCP Registry has all expected fetchers registered" do
    # This test verifies that the initializer properly registered all fetchers
    expected_fetchers = [
      :database, :recent_orders, :user_activity,
      :http, :github_repo, :github_info, :slack_messages,
      :file, :parse_document, :document_summary, :extract_text,
      :semantic_memory, :semantic_search, :find_similar,
      :code, :find_methods, :search_code
    ]

    expected_fetchers.each do |fetcher_key|
      assert Mcp::Registry.registered?(fetcher_key), 
             "Expected fetcher '#{fetcher_key}' to be registered"
      
      fetcher_class = Mcp::Registry.get(fetcher_key)
      assert fetcher_class.respond_to?(:fetch), 
             "Fetcher '#{fetcher_key}' should respond to :fetch"
    end
  end

  test "MCP Context API works with multiple fetchers" do
    context = Mcp::Context.new(user: @user)
    
    # Fetch recent orders
    orders_data = context.fetch(:recent_orders, limit: 3)
    assert orders_data.key?(:count)
    assert_equal 2, orders_data[:count]
    
    # Check context state
    assert context.success?(:recent_orders)
    assert_not context.error?(:recent_orders)
    
    # Get all context data
    all_data = context.to_h
    assert all_data.key?(:user)
    assert all_data.key?(:recent_orders)
  end

  test "specific fetchers have correct metadata" do
    # Test RecentOrders fetcher
    recent_orders_meta = Mcp::Fetcher::RecentOrders.metadata
    assert_equal 'Mcp::Fetcher::RecentOrders', recent_orders_meta[:name]
    assert_includes recent_orders_meta[:allowed_params], :user
    assert_includes recent_orders_meta[:allowed_params], :limit
    
    # Test GitHubInfo fetcher
    github_meta = Mcp::Fetcher::GitHubInfo.metadata
    assert_equal 'Mcp::Fetcher::GitHubInfo', github_meta[:name]
    assert_includes github_meta[:allowed_params], :username
    assert_includes github_meta[:allowed_params], :github_token
    
    # Test DocumentSummary fetcher
    doc_meta = Mcp::Fetcher::DocumentSummary.metadata
    assert_equal 'Mcp::Fetcher::DocumentSummary', doc_meta[:name]
    assert_includes doc_meta[:allowed_params], :file_path
    assert_includes doc_meta[:allowed_params], :file_content
  end
end