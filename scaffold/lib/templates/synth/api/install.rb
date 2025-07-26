# frozen_string_literal: true

# API module installer for Rails SaaS Starter Template
# Provides JSON:API compliant endpoints and OpenAPI schema generation

say 'Installing API module...'

# Create base API controller
create_file 'app/controllers/api/base_controller.rb', <<~RUBY
  # frozen_string_literal: true

  module Api
    class BaseController < ApplicationController
      include JsonApiResponses
      include ErrorHandling
      include Pundit::Authorization
      
      protect_from_forgery with: :null_session
      before_action :authenticate_user!
      before_action :set_default_response_format

      private

      def set_default_response_format
        request.format = :json
      end
    end
  end
RUBY

# Create JSON:API response concerns
create_file 'app/controllers/concerns/json_api_responses.rb', <<~RUBY
  # frozen_string_literal: true

  module JsonApiResponses
    extend ActiveSupport::Concern

    private

    def render_jsonapi_resource(resource, serializer_class = nil, status: :ok, meta: {}, include: [])
      serializer_class ||= "\#{resource.class.name}Serializer".constantize
      
      serializer = serializer_class.new(resource, include: include, meta: meta)
      render json: serializer.serializable_hash, status: status
    end

    def render_jsonapi_collection(resources, serializer_class = nil, status: :ok, meta: {}, include: [])
      serializer_class ||= "\#{resources.model.name}Serializer".constantize
      
      serializer = serializer_class.new(resources, include: include, meta: meta)
      render json: serializer.serializable_hash, status: status
    end

    def render_jsonapi_error(status:, title:, detail: nil, code: nil, source: nil)
      error = {
        status: status.to_s,
        title: title
      }
      error[:detail] = detail if detail
      error[:code] = code if code
      error[:source] = source if source

      render json: { errors: [error] }, status: status
    end

    def render_jsonapi_errors(errors, status: :unprocessable_entity)
      formatted_errors = errors.map do |error|
        {
          status: status.to_s,
          title: 'Validation Error',
          detail: error[:detail] || error,
          source: error[:source] || { pointer: "/data/attributes/\#{error[:attribute]}" }
        }
      end

      render json: { errors: formatted_errors }, status: status
    end
  end
RUBY

# Create error handling concern
create_file 'app/controllers/concerns/error_handling.rb', <<~RUBY
  # frozen_string_literal: true

  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
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
          source: { pointer: "/data/attributes/\#{error.attribute}" }
        }
      end
      
      render_jsonapi_errors(errors)
    end

    def handle_unauthorized(exception)
      render_jsonapi_error(
        status: :forbidden,
        title: 'Access denied',
        detail: exception.message
      )
    end
  end
RUBY

# Create base serializer
create_file 'app/serializers/application_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class ApplicationSerializer
    include JSONAPI::Serializer

    def self.inherited(subclass)
      super
      # Set common configuration for all serializers
      subclass.set_key_transform :underscore
    end
  end
RUBY

# Create example API controller for workspaces
create_file 'app/controllers/api/v1/workspaces_controller.rb', <<~RUBY
  # frozen_string_literal: true

  module Api
    module V1
      class WorkspacesController < Api::BaseController
        before_action :set_workspace, only: [:show, :update, :destroy]

        # GET /api/v1/workspaces
        def index
          workspaces = policy_scope(Workspace).includes(:memberships)
          render_jsonapi_collection(workspaces, WorkspaceSerializer, include: [:memberships])
        end

        # GET /api/v1/workspaces/:id
        def show
          authorize @workspace
          render_jsonapi_resource(@workspace, WorkspaceSerializer, include: [:memberships])
        end

        # POST /api/v1/workspaces
        def create
          workspace = Workspace.new(workspace_params)
          authorize workspace

          if workspace.save
            # Create membership for the creator
            workspace.memberships.create!(user: current_user, role: 'admin')
            render_jsonapi_resource(workspace, WorkspaceSerializer, status: :created)
          else
            render_jsonapi_errors(workspace.errors.full_messages)
          end
        end

        # PATCH/PUT /api/v1/workspaces/:id
        def update
          authorize @workspace

          if @workspace.update(workspace_params)
            render_jsonapi_resource(@workspace, WorkspaceSerializer)
          else
            render_jsonapi_errors(@workspace.errors.full_messages)
          end
        end

        # DELETE /api/v1/workspaces/:id
        def destroy
          authorize @workspace
          @workspace.destroy!
          head :no_content
        end

        private

        def set_workspace
          @workspace = Workspace.find(params[:id])
        end

        def workspace_params
          params.require(:data).require(:attributes).permit(:name, :slug)
        end
      end
    end
  end
RUBY

# Create workspace serializer
create_file 'app/serializers/workspace_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class WorkspaceSerializer < ApplicationSerializer
    attributes :name, :slug, :created_at, :updated_at

    has_many :memberships, serializer: MembershipSerializer
  end
RUBY

# Create membership serializer
create_file 'app/serializers/membership_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class MembershipSerializer < ApplicationSerializer
    attributes :role, :created_at, :updated_at

    belongs_to :user, serializer: UserSerializer
    belongs_to :workspace, serializer: WorkspaceSerializer
  end
RUBY

# Create user serializer
create_file 'app/serializers/user_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class UserSerializer < ApplicationSerializer
    attributes :email, :created_at, :updated_at

    # Don't expose sensitive fields by default
    # Add :first_name, :last_name, etc. as needed
  end
RUBY

# Add API routes
route <<~RUBY
  namespace :api do
    namespace :v1 do
      resources :workspaces, except: [:new, :edit]
    end
  end
RUBY

# Configure rswag for OpenAPI documentation
initializer 'rswag.rb', <<~RUBY
  # frozen_string_literal: true

  Rswag::Ui.configure do |c|
    c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'
  end

  Rswag::Api.configure do |c|
    c.swagger_root = Rails.root.to_s + '/swagger'
  end
RUBY

# Create swagger helper for specs
create_file 'spec/swagger_helper.rb', <<~RUBY
  # frozen_string_literal: true

  require 'rails_helper'

  RSpec.configure do |config|
    # Specify a root folder where Swagger JSON files are generated
    # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
    # to ensure that it's configured to serve Swagger from the same folder
    config.swagger_root = Rails.root.join('swagger').to_s

    # Define one or more Swagger documents and provide global metadata for each one
    # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
    # be generated at the provided relative path under swagger_root
    # By default, the operations defined in spec files are added to the first
    # document below. You can override this behavior by adding a swagger_doc tag to the
    # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
    config.swagger_docs = {
      'v1/swagger.yaml' => {
        openapi: '3.0.1',
        info: {
          title: 'Rails SaaS Starter API V1',
          version: 'v1',
          description: 'API documentation for Rails SaaS Starter template applications',
          contact: {
            name: 'API Support',
            url: 'https://github.com/mitchellfyi/rails-starter'
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
            Error: {
              type: :object,
              properties: {
                errors: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      status: { type: :string },
                      title: { type: :string },
                      detail: { type: :string },
                      code: { type: :string },
                      source: {
                        type: :object,
                        properties: {
                          pointer: { type: :string }
                        }
                      }
                    },
                    required: [:status, :title]
                  }
                }
              },
              required: [:errors]
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

    # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
    # The swagger_docs configuration option has the filename including format in
    # the key, this may want to be changed to avoid putting yaml in json files.
    # Defaults to json. Accepts ':json' and ':yaml'.
    config.swagger_format = :yaml
  end
RUBY

# Create example API spec
create_file 'spec/requests/api/v1/workspaces_spec.rb', <<~RUBY
  # frozen_string_literal: true

  require 'swagger_helper'

  RSpec.describe 'api/v1/workspaces', type: :request do
    path '/api/v1/workspaces' do
      get('list workspaces') do
        tags 'Workspaces'
        description 'Retrieves all workspaces for the authenticated user'
        produces 'application/json'
        security [bearerAuth: []]

        response(200, 'successful') do
          schema type: :object,
                 properties: {
                   data: {
                     type: :array,
                     items: {
                       type: :object,
                       properties: {
                         id: { type: :string },
                         type: { type: :string, enum: ['workspace'] },
                         attributes: {
                           type: :object,
                           properties: {
                             name: { type: :string },
                             slug: { type: :string },
                             created_at: { type: :string, format: :datetime },
                             updated_at: { type: :string, format: :datetime }
                           },
                           required: [:name, :slug]
                         },
                         relationships: {
                           type: :object,
                           properties: {
                             memberships: {
                               type: :object,
                               properties: {
                                 data: {
                                   type: :array,
                                   items: {
                                     type: :object,
                                     properties: {
                                       id: { type: :string },
                                       type: { type: :string, enum: ['membership'] }
                                     }
                                   }
                                 }
                               }
                             }
                           }
                         }
                       },
                       required: [:id, :type, :attributes]
                     }
                   }
                 },
                 required: [:data]

          let(:user) { create(:user) }
          let(:workspace) { create(:workspace) }
          let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'admin') }

          before { sign_in user }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['data']).to be_an(Array)
            expect(data['data'].first['type']).to eq('workspace')
          end
        end

        response(401, 'unauthorized') do
          schema '$ref' => '#/components/schemas/Error'
          run_test!
        end
      end

      post('create workspace') do
        tags 'Workspaces'
        description 'Creates a new workspace'
        consumes 'application/json'
        produces 'application/json'
        security [bearerAuth: []]

        parameter name: :workspace, in: :body, schema: {
          type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                type: { type: :string, enum: ['workspace'] },
                attributes: {
                  type: :object,
                  properties: {
                    name: { type: :string },
                    slug: { type: :string }
                  },
                  required: [:name, :slug]
                }
              },
              required: [:type, :attributes]
            }
          },
          required: [:data]
        }

        response(201, 'created') do
          let(:user) { create(:user) }
          let(:workspace) do
            {
              data: {
                type: 'workspace',
                attributes: {
                  name: 'Test Workspace',
                  slug: 'test-workspace'
                }
              }
            }
          end

          before { sign_in user }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['data']['type']).to eq('workspace')
            expect(data['data']['attributes']['name']).to eq('Test Workspace')
          end
        end

        response(422, 'unprocessable entity') do
          schema '$ref' => '#/components/schemas/Error'
          
          let(:user) { create(:user) }
          let(:workspace) do
            {
              data: {
                type: 'workspace',
                attributes: {
                  name: '',
                  slug: ''
                }
              }
            }
          end

          before { sign_in user }

          run_test!
        end

        response(401, 'unauthorized') do
          schema '$ref' => '#/components/schemas/Error'
          let(:workspace) { { data: { type: 'workspace', attributes: { name: 'Test', slug: 'test' } } } }
          run_test!
        end
      end
    end

    path '/api/v1/workspaces/{id}' do
      parameter name: 'id', in: :path, type: :string, description: 'Workspace ID'

      get('show workspace') do
        tags 'Workspaces'
        description 'Retrieves a specific workspace'
        produces 'application/json'
        security [bearerAuth: []]

        response(200, 'successful') do
          let(:user) { create(:user) }
          let(:workspace) { create(:workspace) }
          let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'admin') }
          let(:id) { workspace.id }

          before { sign_in user }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['data']['type']).to eq('workspace')
            expect(data['data']['id']).to eq(workspace.id.to_s)
          end
        end

        response(404, 'not found') do
          schema '$ref' => '#/components/schemas/Error'
          let(:user) { create(:user) }
          let(:id) { 'invalid' }
          before { sign_in user }
          run_test!
        end

        response(401, 'unauthorized') do
          schema '$ref' => '#/components/schemas/Error'
          let(:id) { 'any' }
          run_test!
        end
      end
    end
  end
RUBY

# Create factories for testing
create_file 'spec/factories/workspaces.rb', <<~RUBY
  # frozen_string_literal: true

  FactoryBot.define do
    factory :workspace do
      name { Faker::Company.name }
      slug { Faker::Internet.slug }
    end
  end
RUBY

create_file 'spec/factories/memberships.rb', <<~RUBY
  # frozen_string_literal: true

  FactoryBot.define do
    factory :membership do
      association :user
      association :workspace
      role { 'member' }

      trait :admin do
        role { 'admin' }
      end

      trait :owner do
        role { 'owner' }
      end
    end
  end
RUBY

# Add Pundit policy for Workspace
create_file 'app/policies/application_policy.rb', <<~RUBY
  # frozen_string_literal: true

  class ApplicationPolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index?
      false
    end

    def show?
      false
    end

    def create?
      false
    end

    def new?
      create?
    end

    def update?
      false
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    class Scope
      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        raise NotImplementedError, "You must define #resolve in \#{self.class}"
      end

      private

      attr_reader :user, :scope
    end
  end
RUBY

create_file 'app/policies/workspace_policy.rb', <<~RUBY
  # frozen_string_literal: true

  class WorkspacePolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      user_is_member?
    end

    def create?
      user.present?
    end

    def update?
      user_is_admin_or_owner?
    end

    def destroy?
      user_is_owner?
    end

    class Scope < Scope
      def resolve
        if user.present?
          scope.joins(:memberships).where(memberships: { user: user })
        else
          scope.none
        end
      end
    end

    private

    def user_is_member?
      return false unless user.present?
      
      record.memberships.exists?(user: user)
    end

    def user_is_admin_or_owner?
      return false unless user.present?
      
      record.memberships.exists?(user: user, role: %w[admin owner])
    end

    def user_is_owner?
      return false unless user.present?
      
      record.memberships.exists?(user: user, role: 'owner')
    end
  end
RUBY

# Add Rake task for generating OpenAPI schema
create_file 'lib/tasks/api.rake', <<~RUBY
  # frozen_string_literal: true

  namespace :api do
    desc 'Generate OpenAPI schema from RSpec tests'
    task generate_schema: :environment do
      require 'rswag/specs/rake_task'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end

    desc 'Validate that OpenAPI schema is up to date'
    task validate_schema: :environment do
      # Store current schema
      current_schema = File.read(Rails.root.join('swagger/v1/swagger.yaml')) if File.exist?(Rails.root.join('swagger/v1/swagger.yaml'))
      
      # Generate new schema
      Rake::Task['api:generate_schema'].invoke
      
      # Compare with current
      new_schema = File.read(Rails.root.join('swagger/v1/swagger.yaml'))
      
      if current_schema != new_schema
        puts "❌ OpenAPI schema is out of date. Run 'rake api:generate_schema' to update."
        exit 1
      else
        puts "✅ OpenAPI schema is up to date."
      end
    end
  end
RUBY

# Add rswag mount to routes
route "mount Rswag::Ui::Engine => '/api-docs'"
route "mount Rswag::Api::Engine => '/api-docs'"

say "✅ API module installed successfully!"
say ""
say "The API module provides:"
say "  - JSON:API compliant base controller and response helpers"
say "  - OpenAPI/Swagger documentation with rswag"
say "  - Example workspace API with full CRUD operations"
say "  - Comprehensive test suite with API specs"
say ""
say "Next steps:"
say "  1. Run migrations: rails db:migrate"
say "  2. Generate API documentation: rake api:generate_schema"
say "  3. Visit API docs at: http://localhost:3000/api-docs"
say "  4. Run API tests: bundle exec rspec spec/requests/api/"