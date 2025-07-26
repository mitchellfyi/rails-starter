# frozen_string_literal: true

module Mcp
  module Fetcher
    # Specialized fetcher for retrieving recent orders for a user
    # Provides common order data patterns for e-commerce/SaaS applications
    #
    # Example:
    #   Mcp::Registry.register(:recent_orders, Mcp::Fetcher::RecentOrders)
    #   
    #   context.fetch(:recent_orders, user: current_user, limit: 5)
    class RecentOrders < Database
      def self.allowed_params
        [:user, :workspace, :limit, :since, :status, :include_details]
      end

      def self.required_params
        [:user]
      end

      def self.required_param?(param)
        required_params.include?(param)
      end

      def self.description
        "Fetches recent orders for a user with optional filtering"
      end

      def self.fetch(user:, workspace: nil, limit: 10, since: 1.month.ago, status: nil, include_details: false, **)
        validate_all_params!(user: user, workspace: workspace, limit: limit, since: since, status: status, include_details: include_details)

        # Build conditions for the query
        conditions = { user: user }
        conditions[:workspace] = workspace if workspace
        conditions[:status] = status if status
        conditions[:created_at] = since.. if since

        # Fetch orders using parent Database fetcher
        order_data = super(
          model: 'Order',
          conditions: conditions,
          limit: limit,
          order: 'created_at DESC'
        )

        # Add order-specific formatting
        if order_data[:records].present? && include_details
          order_data[:records] = order_data[:records].map do |order|
            order.merge(
              total_formatted: format_currency(order['total']),
              status_display: order['status']&.humanize,
              days_ago: days_since(order['created_at'])
            )
          end
        end

        # Add summary statistics
        order_data.merge(
          summary: {
            total_value: order_data[:records].sum { |o| o['total']&.to_f || 0 },
            average_value: calculate_average_order_value(order_data[:records]),
            most_recent: order_data[:records].first&.dig('created_at'),
            statuses: order_data[:records].group_by { |o| o['status'] }.transform_values(&:count)
          }
        )
      rescue NameError => e
        # Handle case where Order model doesn't exist
        Rails.logger.warn("RecentOrders: Order model not found - #{e.message}")
        fallback_data(user: user)
      end

      def self.fallback_data(user: nil, **)
        {
          model: 'Order',
          count: 0,
          total_count: 0,
          records: [],
          summary: {
            total_value: 0,
            average_value: 0,
            most_recent: nil,
            statuses: {}
          },
          error: "Order data not available",
          user_id: user&.id
        }
      end

      private

      def self.format_currency(amount)
        return "$0.00" unless amount
        "$#{'%.2f' % amount}"
      end

      def self.calculate_average_order_value(records)
        return 0 if records.empty?
        
        total = records.sum { |o| o['total']&.to_f || 0 }
        (total / records.size).round(2)
      end

      def self.days_since(date_string)
        return nil unless date_string
        
        date = Date.parse(date_string) rescue nil
        return nil unless date
        
        (Date.current - date).to_i
      end
    end
  end
end