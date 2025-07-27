# frozen_string_literal: true

module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_not_found(exception)
    render_jsonapi_error(
      status: :not_found,
      title: 'Resource not found',
      detail: exception.message
    )
  end

  def handle_validation_error(exception)
    errors = exception.record.errors.map do |error|
      {
        attribute: error.attribute,
        detail: error.full_message,
        source: { pointer: "/data/attributes/#{error.attribute}" }
      }
    end
    
    render_jsonapi_errors(errors)
  end

  def handle_parameter_missing(exception)
    render_jsonapi_error(
      status: :bad_request,
      title: 'Missing required parameter',
      detail: "Missing parameter: #{exception.param}",
      source: { parameter: exception.param.to_s }
    )
  end
end