# frozen_string_literal: true

class PromptTemplateSerializer < ApplicationSerializer
  attributes :name, :slug, :description, :template_content, :variables, 
             :version, :status, :created_at, :updated_at

  # Don't expose sensitive template content by default in collection views
  attribute :template_content, if: proc { |record, params| 
    params && params[:detailed] == true 
  }
end