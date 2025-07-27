# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    include JsonApiResponses
    include ErrorHandling
    include PaginationHelpers
    
    protect_from_forgery with: :null_session
    before_action :authenticate_user!
    before_action :set_default_response_format

    private

    def set_default_response_format
      request.format = :json
    end
  end
end