# frozen_string_literal: true

require 'test_helper'

class Mcp::Fetcher::RecentOrdersTest < ActiveSupport::TestCase
  def setup
    @user = OpenStruct.new(id: 1, name: 'Test User')
    @workspace = OpenStruct.new(id: 1, name: 'Test Workspace')
    
    # Mock Order model and records
    @mock_order_class = Class.new do
      def self.all
        OpenStruct.new(
          where: ->(conditions) { self },
          order: ->(order_by) { self },
          limit: ->(limit) { self },
          offset: ->(offset) { self },
          to_a: -> { @mock_records || [] },
          except: ->(args) { self },
          count: -> { @mock_records&.size || 0 }
        )
      end
      
      def self.column_names
        ['id', 'user_id', 'workspace_id', 'total', 'status', 'created_at']
      end
      
      def self.respond_to?(method)
        true
      end
      
      def self.recent(*args)
        self
      end
      
      class << self
        attr_accessor :mock_records
      end
    end

    # Set up mock records
    @mock_records = [
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
    
    @mock_order_class.mock_records = @mock_records
    
    # Stub constantize to return our mock class
    String.any_instance.stubs(:constantize).returns(@mock_order_class)
  end

  test "fetches recent orders for user" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, limit: 5)

    assert_equal 'Order', result[:model]
    assert_equal 2, result[:count]
    assert_equal 2, result[:records].size
    assert result[:summary]
    assert_equal 249.49, result[:summary][:total_value]
    assert_equal 124.75, result[:summary][:average_value]
  end

  test "applies user scoping" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, workspace: @workspace, limit: 10)
    
    assert_equal 'Order', result[:model]
    assert result[:query_info]
  end

  test "includes order details when requested" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, include_details: true)
    
    first_order = result[:records].first
    assert_includes first_order.keys, 'total_formatted'
    assert_includes first_order.keys, 'status_display'
    assert_includes first_order.keys, 'days_ago'
  end

  test "filters by status" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, status: 'completed')
    
    assert_equal 'Order', result[:model]
    assert result[:query_info][:conditions].key?(:status)
  end

  test "filters by date range" do
    since_date = 1.week.ago
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, since: since_date)
    
    assert result[:query_info][:conditions].key?(:created_at)
  end

  test "validates required parameters" do
    assert_raises ArgumentError do
      Mcp::Fetcher::RecentOrders.fetch(limit: 5) # missing user
    end
  end

  test "handles missing Order model gracefully" do
    String.any_instance.stubs(:constantize).raises(NameError, "Order not found")
    
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user)
    
    assert_equal 0, result[:count]
    assert_includes result[:error], "Order data not available"
  end

  test "provides fallback data" do
    fallback = Mcp::Fetcher::RecentOrders.fallback_data(user: @user)
    
    assert_equal 'Order', fallback[:model]
    assert_equal 0, fallback[:count]
    assert_equal [], fallback[:records]
    assert_equal @user.id, fallback[:user_id]
  end

  test "formats currency correctly" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user, include_details: true)
    
    formatted_total = result[:records].first['total_formatted']
    assert_match /\$\d+\.\d{2}/, formatted_total
  end

  test "calculates summary statistics" do
    result = Mcp::Fetcher::RecentOrders.fetch(user: @user)
    
    summary = result[:summary]
    assert_equal 249.49, summary[:total_value]
    assert_equal 124.75, summary[:average_value]
    assert summary[:statuses].is_a?(Hash)
    assert_equal 1, summary[:statuses]['completed']
    assert_equal 1, summary[:statuses]['pending']
  end
end