# frozen_string_literal: true

class Admin::SchemaController < Admin::BaseController
  def index
    @models = get_application_models
    @connection = ActiveRecord::Base.connection
    @tables = @connection.tables.sort
  end

  def show
    @model_name = params[:id]
    @model = get_model_class(@model_name)
    
    if @model.nil?
      redirect_to admin_schema_index_path, alert: "Model '#{@model_name}' not found."
      return
    end

    @table_name = @model.table_name
    @columns = @model.columns
    @indexes = ActiveRecord::Base.connection.indexes(@table_name)
    @associations = get_model_associations(@model)
    @validations = get_model_validations(@model)
    @sample_records = @model.limit(5) if @model.respond_to?(:limit)
  end

  def query
    @tables = ActiveRecord::Base.connection.tables.sort
    @query_result = nil
    @error = nil

    if params[:sql].present?
      begin
        sql = sanitize_query(params[:sql])
        @query_result = execute_safe_query(sql)
      rescue => e
        @error = e.message
      end
    end
  end

  def explain
    if params[:sql].present?
      begin
        sql = sanitize_query(params[:sql])
        @explanation = ActiveRecord::Base.connection.explain(sql)
      rescue => e
        @error = e.message
      end
    end

    render json: { explanation: @explanation, error: @error }
  end

  private

  def get_application_models
    models = []
    
    # Get all model files
    model_files = Dir[Rails.root.join('app/models/**/*.rb')]
    
    model_files.each do |file|
      # Extract class name from file path
      class_name = file.gsub(Rails.root.join('app/models/').to_s, '')
                      .gsub('.rb', '')
                      .camelize
      
      begin
        klass = class_name.constantize
        if klass < ActiveRecord::Base && !klass.abstract_class?
          models << {
            name: klass.name,
            table_name: klass.table_name,
            count: klass.count
          }
        end
      rescue NameError, LoadError
        # Skip if class doesn't exist or can't be loaded
      end
    end
    
    models.sort_by { |m| m[:name] }
  end

  def get_model_class(model_name)
    begin
      model_name.constantize
    rescue NameError
      nil
    end
  end

  def get_model_associations(model)
    associations = {}
    
    model.reflect_on_all_associations.each do |association|
      associations[association.macro] ||= []
      associations[association.macro] << {
        name: association.name,
        class_name: association.class_name,
        foreign_key: association.foreign_key,
        through: association.options[:through]
      }
    end
    
    associations
  end

  def get_model_validations(model)
    validations = []
    
    model.validators.each do |validator|
      validator.attributes.each do |attribute|
        validations << {
          attribute: attribute,
          type: validator.class.name.demodulize,
          options: validator.options.except(:class)
        }
      end
    end
    
    validations
  end

  def sanitize_query(sql)
    # Remove dangerous SQL commands
    dangerous_keywords = %w[DELETE DROP INSERT UPDATE ALTER CREATE TRUNCATE EXEC EXECUTE]
    
    dangerous_keywords.each do |keyword|
      if sql.upcase.include?(keyword.upcase)
        raise "Dangerous SQL command '#{keyword}' not allowed"
      end
    end
    
    # Limit to SELECT queries only
    unless sql.strip.upcase.start_with?('SELECT')
      raise "Only SELECT queries are allowed"
    end
    
    sql
  end

  def execute_safe_query(sql)
    # Add LIMIT if not present
    unless sql.upcase.include?('LIMIT')
      sql += ' LIMIT 100'
    end
    
    result = ActiveRecord::Base.connection.exec_query(sql)
    
    {
      columns: result.columns,
      rows: result.rows,
      count: result.rows.length
    }
  end
end