# frozen_string_literal: true

# API module installer for Rails SaaS Starter Template
# Provides JSON:API compliant endpoints and OpenAPI schema generation

say 'Installing API module...'

# Create domain-specific directories
run 'mkdir -p app/domains/api/app/{controllers/api/v1,controllers/concerns,serializers,policies}'
run 'mkdir -p app/domains/api/lib/tasks'
run 'mkdir -p spec/domains/api/{requests/api/v1,factories}'

# Create base API controller
create_file 'app/domains/api/app/controllers/api/base_controller.rb', <<~RUBY
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
RUBY

# Create JSON:API response concerns
create_file 'app/domains/api/app/controllers/concerns/json_api_responses.rb', <<~RUBY
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
          source: error[:source] || { pointer: "/data/attributes/#{error[:attribute]}" }
        }
      end

      render json: { errors: formatted_errors }, status: status
    end
  end
RUBY

# Create error handling concern
create_file 'app/domains/api/app/controllers/concerns/error_handling.rb', <<~RUBY
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
RUBY

# Create pagination helpers
create_file 'app/domains/api/app/controllers/concerns/pagination_helpers.rb', <<~RUBY
  # frozen_string_literal: true

  module PaginationHelpers
    extend ActiveSupport::Concern

    private

    # Paginate collection and return with JSON:API meta information
    def paginate_collection(collection, per_page: 25)
      page = params[:page]&.fetch(:number, 1)&.to_i || 1
      per_page = params[:page]&.fetch(:size, per_page)&.to_i || per_page
      
      # Ensure reasonable limits
      per_page = [per_page, 100].min
      per_page = [per_page, 1].max
      
      paginated = collection.page(page).per(per_page)
      
      {
        collection: paginated,
        meta: pagination_meta(paginated)
      }
    end

    # Generate pagination links according to JSON:API spec
    def pagination_links(collection, base_url = request.base_url + request.path)
      return {} unless collection.respond_to?(:current_page)

      links = {}
      current_page = collection.current_page
      total_pages = collection.total_pages
      per_page = collection.limit_value

      # Self link
      links[:self] = paginated_url(base_url, current_page, per_page)

      # First and last
      links[:first] = paginated_url(base_url, 1, per_page)
      links[:last] = paginated_url(base_url, total_pages, per_page) if total_pages > 0

      # Previous and next
      if current_page > 1
        links[:prev] = paginated_url(base_url, current_page - 1, per_page)
      end

      if current_page < total_pages
        links[:next] = paginated_url(base_url, current_page + 1, per_page)
      end

      links
    end

    def paginated_url(base_url, page, per_page)
      uri = URI(base_url)
      query_params = Rack::Utils.parse_query(uri.query)
      query_params['page'] = { 'number' => page, 'size' => per_page }
      uri.query = query_params.to_query
      uri.to_s
    end
  end
RUBY

# Create base serializer
create_file 'app/domains/api/app/serializers/application_serializer.rb', <<~RUBY
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
create_file 'app/domains/api/app/controllers/api/v1/workspaces_controller.rb', <<~RUBY
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
create_file 'app/domains/api/app/serializers/workspace_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class WorkspaceSerializer < ApplicationSerializer
    attributes :name, :slug, :created_at, :updated_at

    has_many :memberships, serializer: MembershipSerializer
  end
RUBY

# Create membership serializer
create_file 'app/domains/api/app/serializers/membership_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class MembershipSerializer < ApplicationSerializer
    attributes :role, :created_at, :updated_at

    belongs_to :user, serializer: UserSerializer
    belongs_to :workspace, serializer: WorkspaceSerializer
  end
RUBY

# Create user serializer
create_file 'app/domains/api/app/serializers/user_serializer.rb', <<~RUBY
  # frozen_string_literal: true

  class UserSerializer < ApplicationSerializer
    attributes :email, :created_at, :updated_at

    # Don't expose sensitive fields by default
    # Add :first_name, :last_name, etc. as needed
  end
RUBY

# Add API routes configuration
create_file 'app/domains/api/config/routes.rb', <<~RUBY
  # frozen_string_literal: true

  # API routes configuration for Rails SaaS Starter Template
  # This file should be included in your main application's routes.rb

  Rails.application.routes.draw do
    # Mount API documentation
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'

    # JSON:API compliant endpoints
    scope module: :api do
      namespace :api do
        namespace :v1 do
          # Add your API resources here
          # Example: resources :posts, only: [:index, :show, :create, :update, :destroy]
        end
      end
    end
  end
RUBY

# Add rswag mount to routes (fallback)
route "mount Rswag::Ui::Engine => '/api-docs' unless Rails.application.routes.routes.any? { |r| r.path.spec.to_s.include?('api-docs') }"
route "mount Rswag::Api::Engine => '/api-docs' unless Rails.application.routes.routes.any? { |r| r.path.spec.to_s.include?('api-docs') }"

# Configure rswag for OpenAPI documentation
initializer 'swagger.rb', <<~RUBY
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
RUBY

# Add RSpec configuration for rswag
create_file '.rspec', <<~RSPEC
  --require spec_helper
  --color
  --format documentation
RSPEC

create_file 'spec/domains/api/rails_helper.rb', <<~RUBY
  # frozen_string_literal: true

  # This file is copied to spec/ when you run 'rails generate rspec:install'
  require 'spec_helper'
  ENV['RAILS_ENV'] ||= 'test'
  require_relative '../config/environment'
  # Prevent database truncation if the environment is production
  abort("The Rails environment is running in production mode!") if Rails.env.production?
  require 'rspec/rails'
  require 'pundit/rspec'

  # Add additional requires below this line. Rails is not loaded until this point!

  # Requires supporting ruby files with custom matchers and macros, etc, in
  # spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
  # run as spec files by default. This behavior can be changed by including
  # `--pattern` in `.rspec` or using the `--pattern` flag with the `rspec` command.
  Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

  # Checks for pending migrations and applies them before tests are run.
  # If you are not using ActiveRecord, you can remove these lines.
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    puts e.to_s.strip
    exit 1
  end

  RSpec.configure do |config|
    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true

    # You can uncomment this line to turn off ActiveRecord support entirely.
    # config.use_active_record = false

    # RSpec Rails can automatically mix in different behaviours to your tests
    # based on their file location, for example enabling you to call `get` and
    # `post` in request specs. You can disable this behaviour by removing
    # the line below, and instead explicitly tag your specs with their type,
    # e.g. RSpec.describe UsersController, type: :controller do # ...
    config.infer_spec_type_from_file_location!

    # Filter lines from Rails gems in backtraces.
    config.filter_rails_from_backtrace!
    # arbitrary gems may also be filtered via:
    # config.filter_gems_from_backtrace("gem name")

    # Include Devise test helpers
    config.include Devise::Test::IntegrationHelpers, type: :request

    # Include Pundit test helpers
    config.include Pundit::RSpec::Matchers

    # FactoryBot configuration
    config.include FactoryBot::Syntax::Methods

    # Database cleaner configuration
    config.before(:suite) do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
RUBY

create_file 'spec/domains/api/spec_helper.rb', <<~RUBY
  # frozen_string_literal: true

  # This file was generated by the `rails generate rspec:install` command. Conventionally, all
  # specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
  # The generated `.rspec` file contains `--require spec_helper` which will cause
  # this file to always be loaded, without a need to explicitly require it in any
  # files.

  # See https://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
  RSpec.configure do |config|
    # rspec-expectations config goes here. You can use an alternate
    # assertion/expectation library such as wrong or the stdlib/minitest
    # assertions if you prefer.
    config.expect_with :rspec do |expectations|
      # This option will default to `true` in RSpec 4. It makes the `description`
      # and `failure_message` of custom matchers include text for helper methods
      # defined using `chain`, e.g.:
      #     be_bigger_than(2).and_smaller_than(4).description
      #     # => "be bigger than 2 and smaller than 4"
      # ...rather than:
      #     # => "be bigger than 2"
      expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    end

    # rspec-mocks config goes here. You can use an alternate test double
    # library such as bogus or mocha by changing the `mock_with` option here.
    config.mock_with :rspec do |mocks|
      # Prevents you from mocking or stubbing a method that does not exist on
      # a real object. This is generally recommended, and will default to
      # `true` in RSpec 4.
      mocks.verify_partial_doubles = true
    end

    # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
    # have no way to turn it off -- the option exists only for backwards
    # compatibility in RSpec 3). It causes shared_group_metadata to be
    # inherited by the host group and example, rather than just the examples.
    # In most cases, you can just ignore this setting. Otherwise, you can remove
    # it and explicitly tag your specs with `:focus` metadata. When nothing
    # is tagged with `:focus`, all examples get run. RSpec also provides
    # aliases for `it`, `describe`, and `context` that include `:focus`
    # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
    config.shared_context_metadata_behavior = :apply_to_host_groups

    # This setting enables warnings. It's recommended, but in some cases may
    # be too noisy due to issues in dependencies.
    config.warnings = true

    # Many RSpec users commonly either run the entire suite or an individual
    # file, and it's useful to allow more verbose output when running an
    # individual spec file.
    if config.files_to_run.one?
      # Use the documentation formatter for detailed output,
      # unless a formatter has already been configured
      # (e.g. via a command-line flag).
      config.default_formatter = "doc"
    end

    # Print the 10 slowest examples and example groups at the
    # end of the spec run, to help surface which specs are running
    # particularly slow.
    config.profile_examples = 10

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = :random

    # Seed global randomization in this process using the `--seed` CLI option.
    # Setting this allows you to use `--seed` to deterministically reproduce
    # test failures related to randomization by passing the same `--seed` value
    # as the one that triggered the failure.
    Kernel.srand config.seed
  end
RUBY

# Create swagger helper for specs
create_file 'spec/domains/api/swagger_helper.rb', <<~RUBY
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
create_file 'spec/domains/api/requests/api/v1/workspaces_spec.rb', <<~RUBY
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
create_file 'spec/domains/api/factories/workspaces.rb', <<~RUBY
  # frozen_string_literal: true

  FactoryBot.define do
    factory :workspace do
      name { Faker::Company.name }
      slug { Faker::Internet.slug }
    end
  end
RUBY

create_file 'spec/domains/api/factories/memberships.rb', <<~RUBY
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
create_file 'app/domains/api/app/policies/application_policy.rb', <<~RUBY
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

create_file 'app/domains/api/app/policies/workspace_policy.rb', <<~RUBY
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
create_file 'app/domains/api/lib/tasks/api.rake', <<~RUBY
  # frozen_string_literal: true

  namespace :api do
    desc 'Generate OpenAPI schema from RSpec tests'
    task generate_schema: :environment do
      require 'rswag/specs/rake_task'
      Rake::Task['rswag:specs:swaggerize'].invoke
      puts "✅ OpenAPI schema generated at swagger/v1/swagger.yaml"
    end

    desc 'Validate that OpenAPI schema is up to date'
    task validate_schema: :environment do
      require 'digest'
      
      schema_path = Rails.root.join('swagger', 'v1', 'swagger.yaml')
      
      unless schema_path.exist?
        puts "❌ OpenAPI schema not found. Run 'rake api:generate_schema' first."
        exit 1
      end
      
      # Store current schema
      current_schema = File.read(schema_path)
      current_checksum = Digest::SHA256.hexdigest(current_schema)
      
      # Generate new schema
      require 'rswag/specs/rake_task'
      Rake::Task['rswag:specs:swaggerize'].invoke
      
      # Compare with current
      new_schema = File.read(schema_path)
      new_checksum = Digest::SHA256.hexdigest(new_schema)
      
      if current_checksum != new_checksum
        puts "❌ OpenAPI schema is out of date. Run 'rake api:generate_schema' to update."
        exit 1
      else
        puts "✅ OpenAPI schema is up to date."
      end
    end

    desc 'Validate API endpoints against OpenAPI specification'
    task validate_endpoints: :environment do
      # This task validates that all API routes have corresponding OpenAPI specs
      puts "🔍 Validating API endpoints against specification..."
      
      api_routes = Rails.application.routes.routes.select do |route|
        route.path.spec.to_s.start_with?('/api/') && 
        !route.path.spec.to_s.include?('api-docs')
      end
      
      puts "📊 Found #{api_routes.count} API routes:"
      api_routes.each do |route|
        method = route.verb.source.gsub(/[\\^\\$]/, '')
        path = route.path.spec.to_s.gsub(/\\(\\.\\w+\\)/, '') # Remove format specifiers
        puts "  #{method.ljust(6)} #{path}"
      end
      
      # Check if swagger spec exists
      schema_path = Rails.root.join('swagger', 'v1', 'swagger.yaml')
      if schema_path.exist?
        require 'yaml'
        spec = YAML.load_file(schema_path)
        documented_paths = spec['paths']&.keys || []
        
        puts "\\n📋 OpenAPI documented paths:"
        documented_paths.each { |path| puts "  #{path}" }
        
        undocumented = api_routes.reject do |route|
          path = route.path.spec.to_s.gsub(/\\(\\.\\w+\\)/, '').gsub(/:(\\w+)/, '{\\1}')
          documented_paths.include?(path)
        end
        
        if undocumented.any?
          puts "\\n⚠️  Undocumented API routes found:"
          undocumented.each do |route|
            method = route.verb.source.gsub(/[\\^\\$]/, '')
            path = route.path.spec.to_s.gsub(/\\(\\.\\w+\\)/, '')
            puts "  #{method.ljust(6)} #{path}"
          end
          puts "\\n💡 Add RSpec request specs for these routes to generate documentation."
        else
          puts "\\n✅ All API routes are documented in OpenAPI specification."
        end
      else
        puts "\\n⚠️  OpenAPI schema not found. Run 'rake api:generate_schema' after adding request specs."
        puts "📝 Create RSpec request specs in spec/requests/api/ to generate documentation."
      end
    end
  end
RUBY

say "✅ API module installed successfully!"
say ""
say "The API module provides:"
say "  - JSON:API compliant base controller and response helpers"
say "  - Automatic error handling with proper JSON:API error format"
say "  - Pagination support with JSON:API meta and links"
say "  - OpenAPI/Swagger documentation generation with rswag"
say "  - Request/response validation and testing infrastructure"
say ""
say "Next steps:"
say "  1. Create API controllers inheriting from Api::BaseController"
say "  2. Create serializers inheriting from ApplicationSerializer"
say "  3. Write RSpec request specs for OpenAPI documentation"
say "  4. Generate API documentation: rake api:generate_schema"
say "  5. Visit API docs at: http://localhost:3000/api-docs"
say "  6. Validate endpoints: rake api:validate_endpoints"