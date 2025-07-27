# frozen_string_literal: true

class PromptExecutionSerializer < ApplicationSerializer
  attributes :context, :created_at, :updated_at

  belongs_to :prompt_template, serializer: :PromptTemplateSerializer, if: proc { |record| record.prompt_template.present? }
end