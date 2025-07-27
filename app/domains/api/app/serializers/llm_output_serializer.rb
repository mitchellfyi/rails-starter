# frozen_string_literal: true

class LLMOutputSerializer < ApplicationSerializer
  attributes :template_name, :model_name, :context, :format, :status, :content,
             :processing_time_seconds, :token_count, :cost_estimate, :job_id,
             :feedback_rating, :feedback_comment, :created_at, :updated_at

  belongs_to :user, serializer: :UserSerializer, if: proc { |record| record.user.present? }
  belongs_to :prompt_execution, serializer: :PromptExecutionSerializer, if: proc { |record| record.prompt_execution.present? }

  attribute :estimated_completion, if: proc { |record| record.status == 'pending' || record.status == 'processing' } do |object|
    30.seconds.from_now.iso8601 if object.status.in?(['pending', 'processing'])
  end
end