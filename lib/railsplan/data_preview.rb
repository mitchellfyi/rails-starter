# frozen_string_literal: true

module RailsPlan
  # Safe database query service for schema-aware chat
  class DataPreview
    class QueryError < StandardError; end
    class UnsafeQueryError < QueryError; end
    
    MAX_LIMIT = 100
    ALLOWED_KEYWORDS = %w[SELECT LIMIT ORDER BY WHERE JOIN INNER LEFT RIGHT FULL OUTER GROUP HAVING DISTINCT].freeze
    FORBIDDEN_KEYWORDS = %w[INSERT UPDATE DELETE DROP CREATE ALTER TRUNCATE EXEC EXECUTE].freeze
    
    def self.query(model:, limit: 10, conditions: nil)
      new.query(model: model, limit: limit, conditions: conditions)
    end
    
    def self.preview_data(table_name, limit: 5)
      new.preview_data(table_name, limit: limit)
    end
    
    def self.explain_query(sql)
      new.explain_query(sql)
    end
    
    def initialize
      @max_limit = MAX_LIMIT
    end
    
    def query(model:, limit: 10, conditions: nil)
      validate_model!(model)
      limit = validate_limit!(limit)
      
      begin
        model_class = model.is_a?(String) ? model.constantize : model
        
        query = model_class.limit(limit)
        query = query.where(conditions) if conditions
        
        results = query.to_a
        
        {
          success: true,
          data: serialize_results(results),
          count: results.length,
          total_count: model_class.count,
          sql: query.to_sql,
          metadata: {
            model: model_class.name,
            table: model_class.table_name,
            limit: limit,
            conditions: conditions
          }
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          data: [],
          count: 0
        }
      end
    end
    
    def preview_data(table_name, limit: 5)
      validate_table_name!(table_name)
      limit = validate_limit!(limit)
      
      return { success: false, error: "ActiveRecord not available" } unless defined?(ActiveRecord::Base)
      
      begin
        # Try to find the model class
        model_class = find_model_for_table(table_name)
        
        if model_class
          query(model: model_class, limit: limit)
        else
          # Fall back to raw SQL if no model found
          raw_preview(table_name, limit)
        end
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          data: [],
          count: 0
        }
      end
    end
    
    def explain_query(sql)
      validate_sql_safety!(sql)
      
      return { success: false, error: "ActiveRecord not available" } unless defined?(ActiveRecord::Base)
      
      begin
        explanation = ActiveRecord::Base.connection.execute("EXPLAIN #{sql}")
        
        {
          success: true,
          explanation: explanation.to_a,
          sql: sql
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          sql: sql
        }
      end
    end
    
    private
    
    def validate_model!(model)
      return if model.is_a?(String) || model.is_a?(Class)
      
      raise QueryError, "Model must be a string or class"
    end
    
    def validate_limit!(limit)
      limit = limit.to_i
      return 1 if limit < 1
      return @max_limit if limit > @max_limit
      
      limit
    end
    
    def validate_table_name!(table_name)
      unless table_name.is_a?(String) && table_name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
        raise QueryError, "Invalid table name"
      end
    end
    
    def validate_sql_safety!(sql)
      sql_upper = sql.upcase.strip
      
      # Check for forbidden keywords
      FORBIDDEN_KEYWORDS.each do |keyword|
        if sql_upper.include?(keyword)
          raise UnsafeQueryError, "SQL contains forbidden keyword: #{keyword}"
        end
      end
      
      # Must start with SELECT
      unless sql_upper.start_with?('SELECT')
        raise UnsafeQueryError, "Only SELECT queries are allowed"
      end
      
      # Check for potential injection patterns
      if sql.include?(';') && !sql.end_with?(';')
        raise UnsafeQueryError, "Multiple statements not allowed"
      end
    end
    
    def find_model_for_table(table_name)
      return nil unless defined?(ActiveRecord::Base)
      
      ActiveRecord::Base.descendants.find do |model_class|
        model_class.table_name == table_name
      end
    end
    
    def raw_preview(table_name, limit)
      return { success: false, error: "ActiveRecord not available" } unless defined?(ActiveRecord::Base)
      
      sql = "SELECT * FROM #{ActiveRecord::Base.connection.quote_table_name(table_name)} LIMIT #{limit}"
      
      begin
        results = ActiveRecord::Base.connection.select_all(sql)
        
        {
          success: true,
          data: results.to_a,
          count: results.length,
          sql: sql,
          metadata: {
            table: table_name,
            limit: limit,
            raw_query: true
          }
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message,
          data: [],
          count: 0
        }
      end
    end
    
    def serialize_results(results)
      results.map do |record|
        if record.respond_to?(:attributes)
          record.attributes
        else
          record.to_h
        end
      end
    end
  end
end