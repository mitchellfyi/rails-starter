# frozen_string_literal: true

module Mcp
  module Fetcher
    # Database fetcher for executing ActiveRecord queries and scopes
    # to retrieve data for prompt contexts.
    #
    # Example:
    #   # Register a fetcher for recent orders
    #   Mcp::Registry.register(:recent_orders, Mcp::Fetcher::Database)
    #
    #   # Use in context
    #   context.fetch(:recent_orders, 
    #     model: 'Order', 
    #     scope: :recent, 
    #     scope_args: [1.week.ago],
    #     user: current_user,
    #     limit: 10
    #   )
    class Database < Base
      def self.allowed_params
        [:model, :scope, :scope_args, :conditions, :limit, :offset, :order, :user, :workspace]
      end

      def self.required_params
        [:model]
      end

      def self.required_param?(param)
        required_params.include?(param)
      end

      def self.description
        "Fetches data from database using ActiveRecord queries and scopes"
      end

      def self.fetch(model:, scope: nil, scope_args: [], conditions: {}, limit: 100, offset: 0, order: nil, user: nil, workspace: nil, **)
        validate_all_params!(model: model, scope: scope, scope_args: scope_args, conditions: conditions, limit: limit, offset: offset, order: order, user: user, workspace: workspace)
        
        # Get the model class
        model_class = get_model_class(model)
        
        # Start with the base relation
        relation = model_class.all
        
        # Apply user/workspace scoping if the model supports it
        relation = apply_user_scoping(relation, user, workspace)
        
        # Apply custom scope if provided
        if scope.present?
          relation = apply_scope(relation, scope, scope_args)
        end
        
        # Apply conditions
        if conditions.present?
          relation = relation.where(conditions)
        end
        
        # Apply ordering
        if order.present?
          relation = relation.order(order)
        end
        
        # Apply limit and offset
        relation = relation.limit(limit).offset(offset)
        
        # Execute query and format results
        records = relation.to_a
        
        {
          model: model.to_s,
          count: records.size,
          total_count: get_total_count(relation),
          records: serialize_records(records),
          query_info: {
            scope: scope,
            conditions: conditions,
            limit: limit,
            offset: offset,
            order: order
          }
        }
      end

      def self.fallback_data(model: nil, **)
        {
          model: model&.to_s,
          count: 0,
          total_count: 0,
          records: [],
          error: "Failed to fetch data from database",
          query_info: {}
        }
      end

      private

      # Get model class from string or constant
      def self.get_model_class(model)
        case model
        when String, Symbol
          model.to_s.constantize
        when Class
          model
        else
          raise ArgumentError, "Model must be a string, symbol, or class"
        end
      rescue NameError => e
        raise ArgumentError, "Invalid model: #{model} (#{e.message})"
      end

      # Apply user/workspace scoping if the model supports it
      def self.apply_user_scoping(relation, user, workspace)
        model_class = relation.klass
        
        # Apply workspace scoping
        if workspace && model_class.column_names.include?('workspace_id')
          relation = relation.where(workspace: workspace)
        end
        
        # Apply user scoping
        if user && model_class.column_names.include?('user_id')
          relation = relation.where(user: user)
        end
        
        relation
      end

      # Apply a named scope with arguments
      def self.apply_scope(relation, scope, scope_args)
        if relation.klass.respond_to?(scope)
          if scope_args.present?
            relation.public_send(scope, *scope_args)
          else
            relation.public_send(scope)
          end
        else
          Rails.logger.warn("MCP Database: Scope '#{scope}' not found on #{relation.klass}")
          relation
        end
      end

      # Get total count without limit/offset
      def self.get_total_count(relation)
        # Remove limit and offset for count
        relation.except(:limit, :offset).count
      rescue => e
        Rails.logger.warn("MCP Database: Could not get total count: #{e.message}")
        nil
      end

      # Serialize records to hash format
      def self.serialize_records(records)
        records.map do |record|
          if record.respond_to?(:as_json)
            record.as_json
          else
            record.attributes
          end
        end
      rescue => e
        Rails.logger.warn("MCP Database: Could not serialize records: #{e.message}")
        []
      end
    end
  end
end