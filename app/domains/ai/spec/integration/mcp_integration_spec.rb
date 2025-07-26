# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "MCP Integration" do
  let(:user) { double('User', id: 1, name: 'Test User') }
  let(:workspace) { double('Workspace', id: 1, name: 'Test Workspace') }

  before do
    # Clear registry and register test fetchers
    Mcp::Registry.clear!
    
    # Simple test fetcher
    test_fetcher = Class.new(Mcp::Fetcher::Base) do
      def self.allowed_params
        [:user, :workspace, :param1, :param2]
      end
      
      def self.fetch(user: nil, workspace: nil, param1: nil, param2: nil, **)
        {
          user_id: user&.id,
          workspace_id: workspace&.id,
          param1: param1,
          param2: param2,
          fetched_at: Time.current
        }
      end
      
      def self.description
        "Test fetcher for integration tests"
      end
    end
    
    # Failing fetcher with fallback
    failing_fetcher = Class.new(Mcp::Fetcher::Base) do
      def self.fetch(**)
        raise StandardError, "Simulated failure"
      end
      
      def self.fallback_data(**params)
        { fallback: true, error: "Fetcher failed", params: params }
      end
    end
    
    Mcp::Registry.register(:test_fetcher, test_fetcher)
    Mcp::Registry.register(:failing_fetcher, failing_fetcher)
  end

  after { Mcp::Registry.clear! }

  describe "full MCP workflow" do
    it "creates context, fetches data from multiple sources, and handles errors" do
      # Create context with base data
      context = Mcp::Context.new(user: user, workspace: workspace)
      
      # Fetch from successful fetcher
      result1 = context.fetch(:test_fetcher, param1: 'value1')
      expect(result1[:user_id]).to eq(1)
      expect(result1[:param1]).to eq('value1')
      
      # Fetch from failing fetcher (should use fallback)
      result2 = context.fetch(:failing_fetcher, param2: 'value2')
      expect(result2[:fallback]).to be true
      expect(result2[:params][:param2]).to eq('value2')
      
      # Check context state
      expect(context.successful_keys).to eq([:test_fetcher])
      expect(context.error_keys).to eq([:failing_fetcher])
      expect(context.has_errors?).to be true
      
      # Get combined context
      combined = context.to_h
      expect(combined).to include(
        user: user,
        workspace: workspace,
        test_fetcher: hash_including(user_id: 1),
        failing_fetcher: hash_including(fallback: true)
      )
    end

    it "fetches multiple data sources at once" do
      context = Mcp::Context.new(user: user)
      
      # Fetch multiple sources
      context.fetch_multiple(
        :test_fetcher,
        [:test_fetcher, { param1: 'different_value' }]
      )
      
      expect(context.fetched_data).to have_key(:test_fetcher)
      expect(context.successful_keys.size).to eq(1) # Same key, so only one entry
    end

    it "provides access to individual fetched data" do
      context = Mcp::Context.new(user: user)
      context.fetch(:test_fetcher, param1: 'test_value')
      
      # Access via bracket notation
      data = context[:test_fetcher]
      expect(data[:param1]).to eq('test_value')
      
      # Check success status
      expect(context.success?(:test_fetcher)).to be true
      expect(context.error?(:test_fetcher)).to be false
    end

    it "resets context data" do
      context = Mcp::Context.new(user: user)
      context.fetch(:test_fetcher, param1: 'test')
      context.fetch(:failing_fetcher)
      
      expect(context.fetched_data).not_to be_empty
      expect(context.errors).not_to be_empty
      
      context.reset!
      
      expect(context.fetched_data).to be_empty
      expect(context.errors).to be_empty
      expect(context.base_data).to eq(user: user) # Base data preserved
    end
  end

  describe "registry management" do
    it "manages fetcher registration and unregistration" do
      # Check initial state
      expect(Mcp::Registry.keys).to contain_exactly(:test_fetcher, :failing_fetcher)
      
      # Register new fetcher
      new_fetcher = Class.new { def self.fetch(**params); {}; end }
      Mcp::Registry.register(:new_fetcher, new_fetcher)
      
      expect(Mcp::Registry.registered?(:new_fetcher)).to be true
      expect(Mcp::Registry.keys).to include(:new_fetcher)
      
      # Unregister fetcher
      removed = Mcp::Registry.unregister(:new_fetcher)
      expect(removed).to eq(new_fetcher)
      expect(Mcp::Registry.registered?(:new_fetcher)).to be false
    end
  end

  describe "error handling" do
    it "raises error for unregistered fetcher" do
      context = Mcp::Context.new(user: user)
      
      expect {
        context.fetch(:nonexistent_fetcher)
      }.to raise_error(ArgumentError, /No fetcher registered for key: nonexistent_fetcher/)
    end

    it "provides detailed error messages" do
      context = Mcp::Context.new(user: user)
      context.fetch(:failing_fetcher)
      
      error_msg = context.error_message(:failing_fetcher)
      expect(error_msg).to include("Failed to fetch data for 'failing_fetcher'")
      expect(error_msg).to include("Simulated failure")
    end
  end
end