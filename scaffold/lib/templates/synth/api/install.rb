# frozen_string_literal: true

# Synth API module installer for the Rails SaaS starter template.
# This module creates JSON:API compliant endpoints with OpenAPI documentation.

say_status :api, "Installing API module with JSON:API and OpenAPI"

# Add API-specific gems
add_gem 'jsonapi-serializer', '~> 2.2'
add_gem 'rswag', '~> 2.14'
add_gem 'rswag-api', '~> 2.14'
add_gem 'rswag-ui', '~> 2.14'
add_gem 'rack-cors', '~> 2.0'
add_gem 'versionist', '~> 2.0'

after_bundle do
  # Configure CORS
  initializer 'cors.rb', <<~'RUBY'
    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins Rails.env.development? ? '*' : ['https://yourdomain.com']
        
        resource '/api/*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: true
      end
    end
  RUBY

  # Configure API versioning
  initializer 'versionist.rb', <<~'RUBY'
    Rails.application.config.to_prepare do
      Versionist.configuration do |config|
        config.versioning_strategy = :header
        config.header_name = 'X-API-Version'
        config.default_version = 'v1'
      end
    end
  RUBY

  # Create base API controller
  create_file 'app/controllers/api/base_controller.rb', <<~'RUBY'
    class Api::BaseController < ApplicationController
      include Versionist::VersioningStrategy::Header
      
      protect_from_forgery with: :null_session
      before_action :authenticate_api_user!
      
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_validation_errors
      rescue_from Pundit::NotAuthorizedError, with: :render_unauthorized

      private

      def authenticate_api_user!
        token = request.headers['Authorization']&.split(' ')&.last
        return render_unauthorized unless token

        @current_user = User.joins(:api_tokens).find_by(api_tokens: { token: token, active: true })
        render_unauthorized unless @current_user
      end

      def current_user
        @current_user
      end

      def render_unauthorized
        render json: {
          errors: [{
            status: '401',
            title: 'Unauthorized',
            detail: 'You must provide a valid API token'
          }]
        }, status: :unauthorized
      end

      def render_not_found(exception)
        render json: {
          errors: [{
            status: '404',
            title: 'Not Found',
            detail: exception.message
          }]
        }, status: :not_found
      end

      def render_validation_errors(exception)
        errors = exception.record.errors.map do |error|
          {
            status: '422',
            title: 'Validation Error',
            detail: error.full_message,
            source: { pointer: "/data/attributes/#{error.attribute}" }
          }
        end

        render json: { errors: errors }, status: :unprocessable_entity
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  RUBY

  # Generate API token model
  generate 'model', 'ApiToken', 'user:references', 'token:string', 'name:string', 'last_used_at:datetime', 'active:boolean'

  # Create API serializers
  create_file 'app/serializers/user_serializer.rb', <<~'RUBY'
    class UserSerializer
      include JSONAPI::Serializer
      
      attributes :id, :email, :first_name, :last_name, :created_at, :updated_at
      
      attribute :full_name do |user|
        user.full_name
      end

      attribute :avatar_url do |user|
        user.avatar
      end
    end
  RUBY

  # Create V1 API controllers
  create_file 'app/controllers/api/v1/users_controller.rb', <<~'RUBY'
    class Api::V1::UsersController < Api::BaseController
      api :v1

      def index
        users = User.page(params[:page]).per(params[:per_page] || 25)
        authorize users
        
        render json: UserSerializer.new(users, meta: pagination_meta(users))
      end

      def show
        user = User.find(params[:id])
        authorize user
        
        render json: UserSerializer.new(user)
      end

      def create
        user = User.new(user_params)
        authorize user
        
        if user.save
          render json: UserSerializer.new(user), status: :created
        else
          raise ActiveRecord::RecordInvalid, user
        end
      end

      def update
        user = User.find(params[:id])
        authorize user
        
        if user.update(user_params)
          render json: UserSerializer.new(user)
        else
          raise ActiveRecord::RecordInvalid, user
        end
      end

      def destroy
        user = User.find(params[:id])
        authorize user
        
        user.destroy
        head :no_content
      end

      private

      def user_params
        params.require(:user).permit(:email, :first_name, :last_name)
      end
    end
  RUBY

  # Create API documentation
  create_file 'spec/requests/api/v1/users_spec.rb', <<~'RUBY'
    require 'swagger_helper'

    RSpec.describe 'api/v1/users', type: :request do
      path '/api/v1/users' do
        get('list users') do
          tags 'Users'
          produces 'application/json'
          parameter name: :page, in: :query, type: :integer, description: 'Page number'
          parameter name: :per_page, in: :query, type: :integer, description: 'Items per page'

          response(200, 'successful') do
            schema type: :object,
              properties: {
                data: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/user' }
                },
                meta: { '$ref' => '#/components/schemas/pagination_meta' }
              }

            let(:page) { 1 }
            let(:per_page) { 10 }
            
            run_test!
          end
        end

        post('create user') do
          tags 'Users'
          consumes 'application/json'
          parameter name: :user, in: :body, schema: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  email: { type: :string },
                  first_name: { type: :string },
                  last_name: { type: :string }
                },
                required: ['email']
              }
            }
          }

          response(201, 'user created') do
            let(:user) { { user: { email: 'test@example.com', first_name: 'Test' } } }
            run_test!
          end

          response(422, 'invalid request') do
            let(:user) { { user: { email: '' } } }
            run_test!
          end
        end
      end

      path '/api/v1/users/{id}' do
        parameter name: 'id', in: :path, type: :string, description: 'id'

        get('show user') do
          tags 'Users'
          produces 'application/json'

          response(200, 'successful') do
            schema '$ref' => '#/components/schemas/user'
            let(:id) { '123' }
            run_test!
          end
        end

        patch('update user') do
          tags 'Users'
          consumes 'application/json'
          parameter name: :user, in: :body, schema: {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  first_name: { type: :string },
                  last_name: { type: :string }
                }
              }
            }
          }

          response(200, 'user updated') do
            let(:id) { '123' }
            let(:user) { { user: { first_name: 'Updated' } } }
            run_test!
          end
        end

        delete('delete user') do
          tags 'Users'

          response(204, 'user deleted') do
            let(:id) { '123' }
            run_test!
          end
        end
      end
    end
  RUBY

  # Create Swagger configuration
  create_file 'spec/swagger_helper.rb', <<~'RUBY'
    require 'rails_helper'

    RSpec.configure do |config|
      config.swagger_root = Rails.root.join('swagger').to_s
      config.swagger_docs = {
        'v1/swagger.yaml' => {
          openapi: '3.0.1',
          info: {
            title: 'API V1',
            version: 'v1'
          },
          paths: {},
          components: {
            schemas: {
              user: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  type: { type: :string },
                  attributes: {
                    type: :object,
                    properties: {
                      email: { type: :string },
                      first_name: { type: :string },
                      last_name: { type: :string },
                      full_name: { type: :string },
                      avatar_url: { type: :string },
                      created_at: { type: :string, format: :datetime },
                      updated_at: { type: :string, format: :datetime }
                    }
                  }
                }
              },
              pagination_meta: {
                type: :object,
                properties: {
                  current_page: { type: :integer },
                  total_pages: { type: :integer },
                  total_count: { type: :integer },
                  per_page: { type: :integer }
                }
              }
            },
            securitySchemes: {
              bearerAuth: {
                type: :http,
                scheme: :bearer
              }
            }
          },
          security: [{ bearerAuth: [] }]
        }
      }
      config.swagger_format = :yaml
    end
  RUBY

  say_status :api, "API module installed. Next steps:"
  say_status :api, "1. Run rails db:migrate"
  say_status :api, "2. Add API routes with versioning"
  say_status :api, "3. Configure CORS for your domain"
  say_status :api, "4. Generate API tokens for users"
  say_status :api, "5. Run rswag:specs:swaggerize to generate docs"
end