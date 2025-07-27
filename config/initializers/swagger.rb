# frozen_string_literal: true

# OpenAPI/Swagger configuration for API documentation

Rails.application.config.to_prepare do
  # Mount Swagger UI at /api-docs
  unless Rails.application.routes.routes.any? { |route| route.path.spec.to_s.include?('api-docs') }
    Rails.application.routes.draw do
      mount Rswag::Ui::Engine => '/api-docs'
      mount Rswag::Api::Engine => '/api-docs'
    end
  end
end