# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Rails SaaS Starter API V1',
        version: 'v1',
        description: 'JSON:API compliant endpoints for Rails SaaS Starter template applications',
        contact: {
          name: 'API Support',
          url: 'https://github.com/mitchellfyi/railsplan'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://{defaultHost}',
          description: 'Production server',
          variables: {
            defaultHost: {
              default: 'your-app.com'
            }
          }
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        },
        schemas: {
          JsonApiError: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    status: { type: :string, description: 'HTTP status code' },
                    title: { type: :string, description: 'Error title' },
                    detail: { type: :string, description: 'Error detail message' },
                    code: { type: :string, description: 'Application-specific error code' },
                    source: {
                      type: :object,
                      properties: {
                        pointer: { type: :string, description: 'JSON pointer to the source' },
                        parameter: { type: :string, description: 'Query parameter that caused the error' }
                      }
                    }
                  },
                  required: [:status, :title]
                }
              }
            },
            required: [:errors]
          },
          JsonApiResource: {
            type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  id: { type: :string },
                  type: { type: :string },
                  attributes: { type: :object },
                  relationships: { type: :object }
                },
                required: [:id, :type, :attributes]
              },
              included: {
                type: :array,
                items: { '$ref' => '#/components/schemas/JsonApiResource/properties/data' }
              },
              meta: { type: :object }
            },
            required: [:data]
          },
          JsonApiCollection: {
            type: :object,
            properties: {
              data: {
                type: :array,
                items: { '$ref' => '#/components/schemas/JsonApiResource/properties/data' }
              },
              included: {
                type: :array,
                items: { '$ref' => '#/components/schemas/JsonApiResource/properties/data' }
              },
              meta: {
                type: :object,
                properties: {
                  pagination: {
                    type: :object,
                    properties: {
                      current_page: { type: :integer },
                      per_page: { type: :integer },
                      total_pages: { type: :integer },
                      total_count: { type: :integer }
                    }
                  }
                }
              }
            },
            required: [:data]
          }
        }
      },
      security: [
        {
          bearerAuth: []
        }
      ]
    }
  }

  # Specify the format of the output Swagger file
  config.swagger_format = :yaml
end