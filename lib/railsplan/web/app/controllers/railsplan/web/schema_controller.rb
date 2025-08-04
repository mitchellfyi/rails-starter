# frozen_string_literal: true

module Railsplan
  module Web
    class SchemaController < ApplicationController
      def index
        @models = extract_models_from_context
        @table_count = @models.length
        @association_count = count_associations
      end
      
      def show
        model_name = params[:model]
        @model = find_model_by_name(model_name)
        
        if @model.nil?
          redirect_to railsplan_web.schema_path, alert: "Model '#{model_name}' not found"
          return
        end
        
        @associations = @model['associations'] || []
        @validations = @model['validations'] || []
        @scopes = @model['scopes'] || []
      end
      
      def search
        query = params[:query].to_s.downcase
        @models = extract_models_from_context
        
        if query.present?
          @models = @models.select do |model|
            model['class_name'].downcase.include?(query) ||
            model['file'].downcase.include?(query) ||
            (model['associations'] || []).any? { |assoc| assoc['name'].downcase.include?(query) }
          end
        end
        
        render json: {
          models: @models.map { |m| format_model_for_json(m) },
          count: @models.length
        }
      end
      
      private
      
      def extract_models_from_context
        return [] unless @app_context && @app_context['models']
        
        @app_context['models'].reject do |model|
          model['class_name'] == 'ApplicationRecord'
        end
      end
      
      def find_model_by_name(name)
        extract_models_from_context.find do |model|
          model['class_name'].downcase == name.downcase
        end
      end
      
      def count_associations
        extract_models_from_context.sum do |model|
          (model['associations'] || []).length
        end
      end
      
      def format_model_for_json(model)
        {
          name: model['class_name'],
          file: model['file'],
          associations_count: (model['associations'] || []).length,
          validations_count: (model['validations'] || []).length,
          scopes_count: (model['scopes'] || []).length
        }
      end
    end
  end
end