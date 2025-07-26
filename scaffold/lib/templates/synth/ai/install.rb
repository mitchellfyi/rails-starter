# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.

say_status :synth_ai, "Installing AI module with PromptTemplate and audit system"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai'
add_gem 'paper_trail'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
    Rails.application.config.ai.default_temperature = 0.7
    Rails.application.config.ai.max_tokens = 4096
    
    # Supported output formats for prompt templates
    Rails.application.config.ai.output_formats = %w[json markdown html_partial text].freeze
  RUBY

  # Set up PaperTrail for versioning
  initializer 'paper_trail.rb', <<~'RUBY'
    PaperTrail.config.track_associations = false
    PaperTrail.config.association_reify_error_behaviour = :warn
  RUBY

  # Create PromptTemplate model and migration
  create_file 'app/models/prompt_template.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptTemplate < ApplicationRecord
      has_paper_trail
      
      validates :name, presence: true, uniqueness: { scope: :workspace_id }
      validates :slug, presence: true, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }
      validates :prompt_body, presence: true
      validates :output_format, presence: true, inclusion: { in: AI_OUTPUT_FORMATS }

      belongs_to :workspace, optional: true
      belongs_to :created_by, class_name: 'User', optional: true
      has_many :prompt_executions, dependent: :destroy

      before_validation :generate_slug, if: -> { slug.blank? && name.present? }

      scope :by_tag, ->(tag) { where('? = ANY(tags)', tag) }
      scope :by_output_format, ->(format) { where(output_format: format) }

      # Extract variable names from prompt body (e.g., {{user_name}}, {{company}})
      def variable_names
        prompt_body.scan(/\{\{(\w+)\}\}/).flatten.uniq
      end

      # Render the prompt with provided context variables
      def render_with_context(context = {})
        rendered = prompt_body.dup
        
        variable_names.each do |var_name|
          value = context[var_name] || context[var_name.to_sym] || ""
          rendered.gsub!("{{#{var_name}}}", value.to_s)
        end
        
        rendered
      end

      # Validate that all required variables are present in context
      def validate_context(context)
        missing_vars = variable_names - context.keys.map(&:to_s) - context.keys.map(&:to_sym).map(&:to_s)
        missing_vars.empty? ? true : missing_vars
      end

      # Generate a preview with sample context
      def preview_with_sample_context
        sample_context = variable_names.map { |var| [var, "[#{var}_value]"] }.to_h
        render_with_context(sample_context)
      end

      private

      def generate_slug
        self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
      end
    end
  RUBY

  # Create PromptExecution model for audit history
  create_file 'app/models/prompt_execution.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptExecution < ApplicationRecord
      belongs_to :prompt_template
      belongs_to :user, optional: true
      belongs_to :workspace, optional: true

      validates :input_context, presence: true
      validates :rendered_prompt, presence: true
      validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

      scope :successful, -> { where(status: 'completed') }
      scope :failed, -> { where(status: 'failed') }
      scope :recent, -> { order(created_at: :desc) }

      def success?
        status == 'completed'
      end

      def failed?
        status == 'failed'
      end

      def duration
        return nil unless started_at && completed_at
        completed_at - started_at
      end
    end
  RUBY

  # Create migrations
  create_file 'db/migrate/001_create_prompt_templates.rb', <<~'RUBY'
    # frozen_string_literal: true

    class CreatePromptTemplates < ActiveRecord::Migration[8.0]
      def change
        create_table :prompt_templates do |t|
          t.string :name, null: false
          t.string :slug, null: false
          t.text :description
          t.text :prompt_body, null: false
          t.string :output_format, null: false, default: 'text'
          t.string :tags, array: true, default: []
          t.references :workspace, foreign_key: true, null: true
          t.references :created_by, foreign_key: { to_table: :users }, null: true
          t.boolean :active, default: true
          
          t.timestamps
        end

        add_index :prompt_templates, [:workspace_id, :name], unique: true
        add_index :prompt_templates, [:workspace_id, :slug], unique: true
        add_index :prompt_templates, :tags, using: 'gin'
        add_index :prompt_templates, :output_format
      end
    end
  RUBY

  create_file 'db/migrate/002_create_prompt_executions.rb', <<~'RUBY'
    # frozen_string_literal: true

    class CreatePromptExecutions < ActiveRecord::Migration[8.0]
      def change
        create_table :prompt_executions do |t|
          t.references :prompt_template, null: false, foreign_key: true
          t.references :user, foreign_key: true, null: true
          t.references :workspace, foreign_key: true, null: true
          
          t.json :input_context, null: false
          t.text :rendered_prompt, null: false
          t.text :output
          t.text :error_message
          t.string :status, null: false, default: 'pending'
          t.string :model_used
          t.integer :tokens_used
          t.datetime :started_at
          t.datetime :completed_at
          
          t.timestamps
        end

        add_index :prompt_executions, :status
        add_index :prompt_executions, :created_at
        add_index :prompt_executions, [:prompt_template_id, :created_at]
      end
    end
  RUBY

  # Create PaperTrail versions table migration
  create_file 'db/migrate/003_create_versions.rb', <<~'RUBY'
    # frozen_string_literal: true
    
    class CreateVersions < ActiveRecord::Migration[8.0]
      TEXT_BYTES = 1_073_741_823

      def change
        create_table :versions, force: true do |t|
          t.string   :item_type, null: false
          t.bigint   :item_id, null: false
          t.string   :event, null: false
          t.string   :whodunnit
          t.text     :object, limit: TEXT_BYTES
          t.text     :object_changes, limit: TEXT_BYTES
          t.datetime :created_at
        end

        add_index :versions, [:item_type, :item_id]
        add_index :versions, :created_at
      end
    end
  RUBY

  # Create controllers
  create_file 'app/controllers/prompt_templates_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptTemplatesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_prompt_template, only: [:show, :edit, :update, :destroy, :preview, :diff]
      before_action :set_workspace, if: -> { params[:workspace_id].present? }

      def index
        @prompt_templates = current_scope.includes(:created_by)
        @prompt_templates = @prompt_templates.by_tag(params[:tag]) if params[:tag].present?
        @prompt_templates = @prompt_templates.by_output_format(params[:output_format]) if params[:output_format].present?
        @prompt_templates = @prompt_templates.order(:name)
      end

      def show
        @executions = @prompt_template.prompt_executions.recent.limit(10)
        @versions = @prompt_template.versions.order(created_at: :desc).limit(10)
      end

      def new
        @prompt_template = current_scope.build
      end

      def create
        @prompt_template = current_scope.build(prompt_template_params)
        @prompt_template.created_by = current_user

        if @prompt_template.save
          redirect_to prompt_template_path(@prompt_template), notice: 'Prompt template was successfully created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @prompt_template.update(prompt_template_params)
          redirect_to prompt_template_path(@prompt_template), notice: 'Prompt template was successfully updated.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @prompt_template.destroy
        redirect_to prompt_templates_path, notice: 'Prompt template was successfully deleted.'
      end

      def preview
        context = JSON.parse(params[:context] || '{}')
        
        begin
          missing_vars = @prompt_template.validate_context(context)
          if missing_vars == true
            @rendered_prompt = @prompt_template.render_with_context(context)
            @validation_errors = nil
          else
            @rendered_prompt = @prompt_template.preview_with_sample_context
            @validation_errors = missing_vars
          end
        rescue JSON::ParserError
          @validation_errors = ['Invalid JSON in context']
          @rendered_prompt = @prompt_template.preview_with_sample_context
        end

        render json: {
          rendered_prompt: @rendered_prompt,
          validation_errors: @validation_errors,
          variable_names: @prompt_template.variable_names
        }
      end

      def diff
        version_id = params[:version_id]
        if version_id && (version = @prompt_template.versions.find_by(id: version_id))
          @previous_version = version.reify
          @current_version = @prompt_template
          
          render json: {
            previous: {
              name: @previous_version&.name,
              prompt_body: @previous_version&.prompt_body,
              description: @previous_version&.description
            },
            current: {
              name: @current_version.name,
              prompt_body: @current_version.prompt_body,
              description: @current_version.description
            }
          }
        else
          render json: { error: 'Version not found' }, status: :not_found
        end
      end

      private

      def set_prompt_template
        @prompt_template = current_scope.find(params[:id])
      end

      def set_workspace
        @workspace = current_user.workspaces.find_by(id: params[:workspace_id])
      end

      def current_scope
        @workspace ? @workspace.prompt_templates : PromptTemplate.where(workspace: nil)
      end

      def prompt_template_params
        params.require(:prompt_template).permit(:name, :description, :prompt_body, :output_format, :active, tags: [])
      end
    end
  RUBY

  create_file 'app/controllers/prompt_executions_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptExecutionsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_prompt_template
      before_action :set_prompt_execution, only: [:show, :destroy]

      def index
        @executions = @prompt_template.prompt_executions.recent.includes(:user)
        @executions = @executions.where(status: params[:status]) if params[:status].present?
      end

      def show
      end

      def create
        context = JSON.parse(params[:context] || '{}')
        
        # Validate context
        missing_vars = @prompt_template.validate_context(context)
        if missing_vars != true
          return render json: { 
            error: "Missing required variables: #{missing_vars.join(', ')}" 
          }, status: :unprocessable_entity
        end

        @execution = @prompt_template.prompt_executions.build(
          user: current_user,
          workspace: @prompt_template.workspace,
          input_context: context,
          rendered_prompt: @prompt_template.render_with_context(context),
          status: 'pending'
        )

        if @execution.save
          # TODO: Enqueue LLM job to process the execution
          render json: { 
            execution_id: @execution.id,
            message: 'Execution queued successfully' 
          }
        else
          render json: { error: @execution.errors.full_messages }, status: :unprocessable_entity
        end
      rescue JSON::ParserError
        render json: { error: 'Invalid JSON in context' }, status: :unprocessable_entity
      end

      def destroy
        @execution.destroy
        redirect_to prompt_template_path(@prompt_template), notice: 'Execution deleted successfully.'
      end

      private

      def set_prompt_template
        @prompt_template = PromptTemplate.find(params[:prompt_template_id])
      end

      def set_prompt_execution
        @execution = @prompt_template.prompt_executions.find(params[:id])
      end
    end
  RUBY

  # Create views
  run 'mkdir -p app/views/prompt_templates'
  create_file 'app/views/prompt_templates/index.html.erb', <<~'ERB'
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Prompt Templates</h1>
          <p class="mt-2 text-sm text-gray-700">Manage your AI prompt templates with versioning and variable interpolation.</p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <%= link_to 'New Template', new_prompt_template_path, class: 'inline-flex items-center justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600' %>
        </div>
      </div>

      <!-- Filters -->
      <div class="mt-6 flex space-x-4">
        <div class="flex-1">
          <%= form_with url: prompt_templates_path, method: :get, local: true, class: 'flex space-x-4' do |form| %>
            <%= form.select :output_format, options_for_select([['All Formats', '']] + ai_output_formats.map { |f| [f.humanize, f] }, params[:output_format]), {}, { class: 'rounded-md border-gray-300 text-sm' } %>
            <%= form.text_field :tag, placeholder: 'Filter by tag', value: params[:tag], class: 'rounded-md border-gray-300 text-sm' %>
            <%= form.submit 'Filter', class: 'rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50' %>
          <% end %>
        </div>
      </div>

      <!-- Templates Grid -->
      <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <% @prompt_templates.each do |template| %>
          <div class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm hover:border-gray-400">
            <div class="flex justify-between items-start">
              <div class="flex-1 min-w-0">
                <h3 class="text-lg font-medium text-gray-900 truncate">
                  <%= link_to template.name, prompt_template_path(template), class: 'hover:text-indigo-600' %>
                </h3>
                <p class="text-sm text-gray-500 mt-1"><%= template.output_format.humanize %></p>
                <% if template.description.present? %>
                  <p class="text-sm text-gray-600 mt-2 line-clamp-2"><%= template.description %></p>
                <% end %>
              </div>
              <span class="<%= template.active? ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800' %> inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                <%= template.active? ? 'Active' : 'Inactive' %>
              </span>
            </div>
            
            <div class="mt-4">
              <div class="flex items-center text-sm text-gray-500">
                <span>Variables: <%= template.variable_names.join(', ') if template.variable_names.any? %></span>
              </div>
              <% if template.tags.any? %>
                <div class="mt-2 flex flex-wrap gap-1">
                  <% template.tags.each do |tag| %>
                    <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-blue-100 text-blue-800">
                      <%= tag %>
                    </span>
                  <% end %>
                </div>
              <% end %>
            </div>
            
            <div class="mt-4 flex justify-between items-center text-xs text-gray-500">
              <span>by <%= template.created_by&.email || 'System' %></span>
              <span><%= time_ago_in_words(template.updated_at) %> ago</span>
            </div>
          </div>
        <% end %>
      </div>

      <% if @prompt_templates.empty? %>
        <div class="text-center py-12">
          <h3 class="mt-2 text-sm font-semibold text-gray-900">No prompt templates</h3>
          <p class="mt-1 text-sm text-gray-500">Get started by creating a new prompt template.</p>
          <div class="mt-6">
            <%= link_to 'New Template', new_prompt_template_path, class: 'inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500' %>
          </div>
        </div>
      <% end %>
    </div>
  ERB

  create_file 'app/views/prompt_templates/show.html.erb', <<~'ERB'
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="lg:flex lg:items-center lg:justify-between">
        <div class="min-w-0 flex-1">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
            <%= @prompt_template.name %>
          </h2>
          <div class="mt-1 flex flex-col sm:mt-0 sm:flex-row sm:flex-wrap sm:space-x-6">
            <div class="mt-2 flex items-center text-sm text-gray-500">
              <span class="<%= @prompt_template.active? ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800' %> inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                <%= @prompt_template.active? ? 'Active' : 'Inactive' %>
              </span>
              <span class="ml-4"><%= @prompt_template.output_format.humanize %></span>
            </div>
          </div>
        </div>
        <div class="mt-5 flex lg:mt-0 lg:ml-4">
          <%= link_to 'Edit', edit_prompt_template_path(@prompt_template), class: 'sm:ml-3 inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500' %>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Main Content -->
        <div class="lg:col-span-2">
          <!-- Description -->
          <% if @prompt_template.description.present? %>
            <div class="bg-white shadow rounded-lg p-6 mb-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Description</h3>
              <p class="text-gray-700"><%= simple_format(@prompt_template.description) %></p>
            </div>
          <% end %>

          <!-- Prompt Body -->
          <div class="bg-white shadow rounded-lg p-6 mb-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Prompt Template</h3>
            <pre class="bg-gray-50 p-4 rounded-md text-sm overflow-x-auto"><%= @prompt_template.prompt_body %></pre>
          </div>

          <!-- Preview Section -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Preview</h3>
            <div class="space-y-4">
              <div>
                <label for="preview-context" class="block text-sm font-medium text-gray-700">Context (JSON)</label>
                <textarea id="preview-context" rows="4" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm" placeholder='{"variable_name": "value"}'></textarea>
              </div>
              <button id="preview-btn" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
                Preview
              </button>
            </div>
            <div id="preview-result" class="mt-6 hidden">
              <h4 class="text-sm font-medium text-gray-900 mb-2">Rendered Prompt:</h4>
              <pre id="preview-output" class="bg-gray-50 p-4 rounded-md text-sm overflow-x-auto"></pre>
              <div id="preview-errors" class="mt-2 hidden">
                <p class="text-sm text-red-600"></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Variables -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Variables</h3>
            <% if @prompt_template.variable_names.any? %>
              <ul class="space-y-2">
                <% @prompt_template.variable_names.each do |var| %>
                  <li class="flex items-center">
                    <code class="bg-gray-100 px-2 py-1 rounded text-sm">{{<%= var %>}}</code>
                  </li>
                <% end %>
              </ul>
            <% else %>
              <p class="text-sm text-gray-500">No variables defined</p>
            <% end %>
          </div>

          <!-- Tags -->
          <% if @prompt_template.tags.any? %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Tags</h3>
              <div class="flex flex-wrap gap-2">
                <% @prompt_template.tags.each do |tag| %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    <%= tag %>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Metadata -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Metadata</h3>
            <dl class="space-y-2 text-sm">
              <div>
                <dt class="font-medium text-gray-900">Created by</dt>
                <dd class="text-gray-700"><%= @prompt_template.created_by&.email || 'System' %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-900">Created</dt>
                <dd class="text-gray-700"><%= @prompt_template.created_at.strftime('%B %d, %Y at %I:%M %p') %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-900">Last updated</dt>
                <dd class="text-gray-700"><%= @prompt_template.updated_at.strftime('%B %d, %Y at %I:%M %p') %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-900">Slug</dt>
                <dd class="text-gray-700"><code><%= @prompt_template.slug %></code></dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

      <!-- Recent Executions -->
      <% if @executions.any? %>
        <div class="mt-8 bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Recent Executions</h3>
          </div>
          <div class="divide-y divide-gray-200">
            <% @executions.each do |execution| %>
              <div class="px-6 py-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <span class="status-<%= execution.status %> inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                      <%= execution.status.humanize %>
                    </span>
                    <span class="ml-4 text-sm text-gray-500">
                      by <%= execution.user&.email || 'System' %>
                    </span>
                  </div>
                  <span class="text-sm text-gray-500">
                    <%= time_ago_in_words(execution.created_at) %> ago
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Version History -->
      <% if @versions.any? %>
        <div class="mt-8 bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Version History</h3>
          </div>
          <div class="divide-y divide-gray-200">
            <% @versions.each do |version| %>
              <div class="px-6 py-4">
                <div class="flex items-center justify-between">
                  <div>
                    <span class="text-sm font-medium text-gray-900">Version <%= version.id %></span>
                    <span class="ml-2 text-sm text-gray-500"><%= version.event.humanize %></span>
                  </div>
                  <div class="flex items-center space-x-2">
                    <button onclick="showDiff(<%= version.id %>)" class="text-sm text-indigo-600 hover:text-indigo-900">
                      View Diff
                    </button>
                    <span class="text-sm text-gray-500">
                      <%= time_ago_in_words(version.created_at) %> ago
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <!-- Diff Modal -->
    <div id="diff-modal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full">
      <div class="relative top-20 mx-auto p-5 border w-11/12 lg:w-3/4 shadow-lg rounded-md bg-white">
        <div class="mt-3">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-medium text-gray-900">Version Diff</h3>
            <button onclick="closeDiff()" class="text-gray-400 hover:text-gray-600">
              <span class="sr-only">Close</span>
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div id="diff-content" class="space-y-4">
            <!-- Diff content will be loaded here -->
          </div>
        </div>
      </div>
    </div>

    <script>
      // Preview functionality
      document.getElementById('preview-btn').addEventListener('click', function() {
        const context = document.getElementById('preview-context').value;
        
        fetch('<%= preview_prompt_template_path(@prompt_template) %>', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          },
          body: JSON.stringify({ context: context })
        })
        .then(response => response.json())
        .then(data => {
          document.getElementById('preview-output').textContent = data.rendered_prompt;
          document.getElementById('preview-result').classList.remove('hidden');
          
          const errorsDiv = document.getElementById('preview-errors');
          if (data.validation_errors && data.validation_errors.length > 0) {
            errorsDiv.querySelector('p').textContent = 'Missing variables: ' + data.validation_errors.join(', ');
            errorsDiv.classList.remove('hidden');
          } else {
            errorsDiv.classList.add('hidden');
          }
        })
        .catch(error => {
          console.error('Error:', error);
          document.getElementById('preview-errors').querySelector('p').textContent = 'Error generating preview';
          document.getElementById('preview-errors').classList.remove('hidden');
        });
      });

      // Diff functionality
      function showDiff(versionId) {
        fetch('<%= diff_prompt_template_path(@prompt_template) %>?version_id=' + versionId)
        .then(response => response.json())
        .then(data => {
          if (data.error) {
            alert('Error loading diff: ' + data.error);
            return;
          }
          
          const diffContent = document.getElementById('diff-content');
          diffContent.innerHTML = `
            <div class="grid grid-cols-2 gap-4">
              <div>
                <h4 class="font-medium text-gray-900 mb-2">Previous Version</h4>
                <div class="space-y-2">
                  <div>
                    <label class="text-sm text-gray-600">Name:</label>
                    <p class="bg-red-50 p-2 rounded text-sm">${data.previous.name || ''}</p>
                  </div>
                  <div>
                    <label class="text-sm text-gray-600">Prompt:</label>
                    <pre class="bg-red-50 p-2 rounded text-sm overflow-x-auto">${data.previous.prompt_body || ''}</pre>
                  </div>
                </div>
              </div>
              <div>
                <h4 class="font-medium text-gray-900 mb-2">Current Version</h4>
                <div class="space-y-2">
                  <div>
                    <label class="text-sm text-gray-600">Name:</label>
                    <p class="bg-green-50 p-2 rounded text-sm">${data.current.name}</p>
                  </div>
                  <div>
                    <label class="text-sm text-gray-600">Prompt:</label>
                    <pre class="bg-green-50 p-2 rounded text-sm overflow-x-auto">${data.current.prompt_body}</pre>
                  </div>
                </div>
              </div>
            </div>
          `;
          
          document.getElementById('diff-modal').classList.remove('hidden');
        })
        .catch(error => {
          console.error('Error:', error);
          alert('Error loading diff');
        });
      }

      function closeDiff() {
        document.getElementById('diff-modal').classList.add('hidden');
      }
    </script>
  ERB

  create_file 'app/views/prompt_templates/_form.html.erb', <<~'ERB'
    <%= form_with model: prompt_template, local: true, class: 'space-y-6' do |form| %>
      <% if prompt_template.errors.any? %>
        <div class="rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">
                <%= pluralize(prompt_template.errors.count, "error") %> prohibited this template from being saved:
              </h3>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc pl-5 space-y-1">
                  <% prompt_template.errors.full_messages.each do |message| %>
                    <li><%= message %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <%= form.label :name, class: 'block text-sm font-medium text-gray-700' %>
          <%= form.text_field :name, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500' %>
        </div>

        <div>
          <%= form.label :slug, class: 'block text-sm font-medium text-gray-700' %>
          <%= form.text_field :slug, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500', placeholder: 'Leave blank to auto-generate' %>
          <p class="mt-1 text-sm text-gray-500">Used for API access and referencing</p>
        </div>
      </div>

      <div>
        <%= form.label :description, class: 'block text-sm font-medium text-gray-700' %>
        <%= form.text_area :description, rows: 3, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500' %>
        <p class="mt-1 text-sm text-gray-500">Describe what this prompt template does</p>
      </div>

      <div>
        <%= form.label :prompt_body, 'Prompt Template', class: 'block text-sm font-medium text-gray-700' %>
        <%= form.text_area :prompt_body, rows: 10, class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 font-mono text-sm', placeholder: 'Enter your prompt template here. Use {{variable_name}} for variables.' %>
        <p class="mt-1 text-sm text-gray-500">Use <code>{{variable_name}}</code> syntax for variables that will be replaced at runtime</p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
        <div>
          <%= form.label :output_format, class: 'block text-sm font-medium text-gray-700' %>
          <%= form.select :output_format, 
                options_for_select(ai_output_formats.map { |f| [f.humanize, f] }, prompt_template.output_format),
                {},
                { class: 'mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500' } %>
        </div>

        <div class="flex items-center">
          <div class="flex items-center h-5">
            <%= form.check_box :active, class: 'h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded' %>
          </div>
          <div class="ml-3 text-sm">
            <%= form.label :active, 'Active', class: 'font-medium text-gray-700' %>
            <p class="text-gray-500">Whether this template is available for use</p>
          </div>
        </div>
      </div>

      <div>
        <%= form.label :tags, class: 'block text-sm font-medium text-gray-700' %>
        <div id="tags-container" class="mt-1">
          <div class="flex flex-wrap gap-2 mb-2" id="current-tags">
            <% (prompt_template.tags || []).each_with_index do |tag, index| %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                <%= tag %>
                <%= form.hidden_field :tags, multiple: true, value: tag, id: "tags_#{index}" %>
                <button type="button" onclick="removeTag(this)" class="ml-1 text-blue-600 hover:text-blue-800">×</button>
              </span>
            <% end %>
          </div>
          <div class="flex">
            <input type="text" id="new-tag" placeholder="Add a tag" class="flex-1 rounded-l-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
            <button type="button" onclick="addTag()" class="px-4 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-600 hover:bg-gray-100">
              Add
            </button>
          </div>
        </div>
        <p class="mt-1 text-sm text-gray-500">Press Enter or click Add to add tags</p>
      </div>

      <div class="flex justify-end space-x-3">
        <%= link_to 'Cancel', prompt_templates_path, class: 'bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500' %>
        <%= form.submit class: 'ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500' %>
      </div>
    <% end %>

    <script>
      let tagIndex = <%= (prompt_template.tags || []).length %>;

      function addTag() {
        const input = document.getElementById('new-tag');
        const tag = input.value.trim();
        
        if (tag && !isDuplicateTag(tag)) {
          const container = document.getElementById('current-tags');
          const tagElement = document.createElement('span');
          tagElement.className = 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800';
          tagElement.innerHTML = `
            ${tag}
            <input type="hidden" name="prompt_template[tags][]" value="${tag}" id="tags_${tagIndex}">
            <button type="button" onclick="removeTag(this)" class="ml-1 text-blue-600 hover:text-blue-800">×</button>
          `;
          container.appendChild(tagElement);
          input.value = '';
          tagIndex++;
        }
      }

      function removeTag(button) {
        button.parentElement.remove();
      }

      function isDuplicateTag(newTag) {
        const existingTags = document.querySelectorAll('#current-tags input[type="hidden"]');
        return Array.from(existingTags).some(input => input.value === newTag);
      }

      // Add tag on Enter key
      document.getElementById('new-tag').addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
          e.preventDefault();
          addTag();
        }
      });
    </script>
  ERB

  create_file 'app/views/prompt_templates/new.html.erb', <<~'ERB'
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">New Prompt Template</h1>
        <p class="mt-2 text-sm text-gray-700">
          Create a new prompt template with variable interpolation and versioning.
        </p>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <%= render 'form', prompt_template: @prompt_template %>
      </div>
    </div>
  ERB

  create_file 'app/views/prompt_templates/edit.html.erb', <<~'ERB'
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Edit Prompt Template</h1>
        <p class="mt-2 text-sm text-gray-700">
          Make changes to "<%= @prompt_template.name %>". Changes will be tracked as new versions.
        </p>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <%= render 'form', prompt_template: @prompt_template %>
      </div>
    </div>
  ERB

  # Add execution views
  run 'mkdir -p app/views/prompt_executions'
  create_file 'app/views/prompt_executions/index.html.erb', <<~'ERB'
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">
            Executions for "<%= @prompt_template.name %>"
          </h1>
          <p class="mt-2 text-sm text-gray-700">History of all executions for this prompt template.</p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <%= link_to 'Back to Template', prompt_template_path(@prompt_template), class: 'inline-flex items-center justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50' %>
        </div>
      </div>

      <!-- Filter -->
      <div class="mt-6">
        <%= form_with url: prompt_template_prompt_executions_path(@prompt_template), method: :get, local: true, class: 'flex space-x-4' do |form| %>
          <%= form.select :status, 
                options_for_select([['All Statuses', '']] + %w[pending processing completed failed].map { |s| [s.humanize, s] }, params[:status]),
                {},
                { class: 'rounded-md border-gray-300 text-sm' } %>
          <%= form.submit 'Filter', class: 'rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50' %>
        <% end %>
      </div>

      <!-- Executions Table -->
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <table class="min-w-full divide-y divide-gray-300">
              <thead>
                <tr>
                  <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0">Status</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">User</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Duration</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Created</th>
                  <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                    <span class="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <% @executions.each do |execution| %>
                  <tr>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-0">
                      <span class="status-<%= execution.status %> inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium">
                        <%= execution.status.humanize %>
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      <%= execution.user&.email || 'System' %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      <%= execution.duration ? "#{execution.duration.round(2)}s" : '-' %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      <%= execution.created_at.strftime('%b %d, %Y %I:%M %p') %>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                      <%= link_to 'View', prompt_template_prompt_execution_path(@prompt_template, execution), class: 'text-indigo-600 hover:text-indigo-900' %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <% if @executions.empty? %>
              <div class="text-center py-12">
                <h3 class="mt-2 text-sm font-semibold text-gray-900">No executions</h3>
                <p class="mt-1 text-sm text-gray-500">No executions have been recorded for this template yet.</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
  ERB

  create_file 'app/views/prompt_executions/show.html.erb', <<~'ERB'
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Execution Details</h1>
            <p class="mt-2 text-sm text-gray-700">
              Execution of "<%= @prompt_template.name %>" template
            </p>
          </div>
          <span class="status-<%= @execution.status %> inline-flex items-center px-3 py-1 rounded-full text-sm font-medium">
            <%= @execution.status.humanize %>
          </span>
        </div>
      </div>

      <div class="space-y-6">
        <!-- Metadata -->
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Execution Metadata</h2>
          <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <dt class="text-sm font-medium text-gray-500">User</dt>
              <dd class="mt-1 text-sm text-gray-900"><%= @execution.user&.email || 'System' %></dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd class="mt-1 text-sm text-gray-900"><%= @execution.status.humanize %></dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Created</dt>
              <dd class="mt-1 text-sm text-gray-900"><%= @execution.created_at.strftime('%B %d, %Y at %I:%M %p') %></dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Duration</dt>
              <dd class="mt-1 text-sm text-gray-900"><%= @execution.duration ? "#{@execution.duration.round(2)} seconds" : 'N/A' %></dd>
            </div>
            <% if @execution.model_used.present? %>
              <div>
                <dt class="text-sm font-medium text-gray-500">Model</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= @execution.model_used %></dd>
              </div>
            <% end %>
            <% if @execution.tokens_used.present? %>
              <div>
                <dt class="text-sm font-medium text-gray-500">Tokens Used</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= number_with_delimiter(@execution.tokens_used) %></dd>
              </div>
            <% end %>
          </dl>
        </div>

        <!-- Input Context -->
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Input Context</h2>
          <pre class="bg-gray-50 p-4 rounded-md text-sm overflow-x-auto"><%= JSON.pretty_generate(@execution.input_context) %></pre>
        </div>

        <!-- Rendered Prompt -->
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Rendered Prompt</h2>
          <pre class="bg-gray-50 p-4 rounded-md text-sm overflow-x-auto"><%= @execution.rendered_prompt %></pre>
        </div>

        <!-- Output -->
        <% if @execution.output.present? %>
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-gray-900 mb-4">Output</h2>
            <pre class="bg-gray-50 p-4 rounded-md text-sm overflow-x-auto"><%= @execution.output %></pre>
          </div>
        <% end %>

        <!-- Error -->
        <% if @execution.error_message.present? %>
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-medium text-red-900 mb-4">Error Message</h2>
            <pre class="bg-red-50 p-4 rounded-md text-sm overflow-x-auto text-red-700"><%= @execution.error_message %></pre>
          </div>
        <% end %>
      </div>

      <div class="mt-8 flex justify-between">
        <%= link_to 'Back to Executions', prompt_template_prompt_executions_path(@prompt_template), class: 'inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50' %>
        <%= link_to 'Back to Template', prompt_template_path(@prompt_template), class: 'inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700' %>
      </div>
    </div>
  ERB

  # Add CSS for status indicators
  create_file 'app/assets/stylesheets/prompt_templates.css', <<~'CSS'
    .status-pending {
      @apply bg-yellow-100 text-yellow-800;
    }

    .status-processing {
      @apply bg-blue-100 text-blue-800;
    }

    .status-completed {
      @apply bg-green-100 text-green-800;
    }

    .status-failed {
      @apply bg-red-100 text-red-800;
    }

    .line-clamp-2 {
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
  CSS

  # Add routes
  route <<~'RUBY'
    resources :prompt_templates do
      member do
        post :preview
        get :diff
      end
      resources :prompt_executions, only: [:index, :show, :create, :destroy]
    end
  RUBY

  # Create test files
  run 'mkdir -p test/models test/controllers test/fixtures'

  # Model tests
  create_file 'test/models/prompt_template_test.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'test_helper'

    class PromptTemplateTest < ActiveSupport::TestCase
      def setup
        @user = users(:one) # Assumes fixture exists
        @prompt_template = PromptTemplate.create!(
          name: 'Test Template',
          prompt_body: 'Hello {{name}}, welcome to {{company}}!',
          output_format: 'text',
          created_by: @user
        )
      end

      test 'should be valid with required attributes' do
        template = PromptTemplate.new(
          name: 'Valid Template',
          prompt_body: 'Test prompt',
          output_format: 'text'
        )
        assert template.valid?
      end

      test 'should require name' do
        template = PromptTemplate.new(prompt_body: 'Test', output_format: 'text')
        assert_not template.valid?
        assert_includes template.errors[:name], "can't be blank"
      end

      test 'should require prompt_body' do
        template = PromptTemplate.new(name: 'Test', output_format: 'text')
        assert_not template.valid?
        assert_includes template.errors[:prompt_body], "can't be blank"
      end

      test 'should require valid output_format' do
        template = PromptTemplate.new(
          name: 'Test',
          prompt_body: 'Test',
          output_format: 'invalid'
        )
        assert_not template.valid?
        assert_includes template.errors[:output_format], 'is not included in the list'
      end

      test 'should generate slug from name if slug is blank' do
        template = PromptTemplate.create!(
          name: 'My Test Template!',
          prompt_body: 'Test',
          output_format: 'text'
        )
        assert_equal 'my_test_template', template.slug
      end

      test 'should not override existing slug' do
        template = PromptTemplate.create!(
          name: 'Test Template',
          slug: 'custom_slug',
          prompt_body: 'Test',
          output_format: 'text'
        )
        assert_equal 'custom_slug', template.slug
      end

      test 'should extract variable names from prompt body' do
        variables = @prompt_template.variable_names
        assert_equal ['name', 'company'], variables
      end

      test 'should handle prompt body without variables' do
        template = PromptTemplate.new(prompt_body: 'No variables here')
        assert_equal [], template.variable_names
      end

      test 'should render with context' do
        context = { 'name' => 'John', 'company' => 'Acme Corp' }
        rendered = @prompt_template.render_with_context(context)
        assert_equal 'Hello John, welcome to Acme Corp!', rendered
      end

      test 'should render with symbol keys in context' do
        context = { name: 'John', company: 'Acme Corp' }
        rendered = @prompt_template.render_with_context(context)
        assert_equal 'Hello John, welcome to Acme Corp!', rendered
      end

      test 'should handle missing variables in context' do
        context = { 'name' => 'John' }
        rendered = @prompt_template.render_with_context(context)
        assert_equal 'Hello John, welcome to !', rendered
      end

      test 'should validate context and return true for complete context' do
        context = { 'name' => 'John', 'company' => 'Acme' }
        assert_equal true, @prompt_template.validate_context(context)
      end

      test 'should validate context and return missing variables' do
        context = { 'name' => 'John' }
        missing = @prompt_template.validate_context(context)
        assert_equal ['company'], missing
      end

      test 'should generate preview with sample context' do
        preview = @prompt_template.preview_with_sample_context
        assert_equal 'Hello [name_value], welcome to [company_value]!', preview
      end

      test 'should track versions with paper_trail' do
        assert_difference '@prompt_template.versions.count', 1 do
          @prompt_template.update!(name: 'Updated Name')
        end
      end

      test 'should scope by tag' do
        template1 = PromptTemplate.create!(
          name: 'Template 1',
          prompt_body: 'Test',
          output_format: 'text',
          tags: ['important', 'customer']
        )
        template2 = PromptTemplate.create!(
          name: 'Template 2', 
          prompt_body: 'Test',
          output_format: 'text',
          tags: ['internal']
        )

        important_templates = PromptTemplate.by_tag('important')
        assert_includes important_templates, template1
        assert_not_includes important_templates, template2
      end

      test 'should scope by output format' do
        json_template = PromptTemplate.create!(
          name: 'JSON Template',
          prompt_body: 'Test',
          output_format: 'json'
        )

        json_templates = PromptTemplate.by_output_format('json')
        assert_includes json_templates, json_template
        assert_not_includes json_templates, @prompt_template
      end
    end
  RUBY

  create_file 'test/models/prompt_execution_test.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'test_helper'

    class PromptExecutionTest < ActiveSupport::TestCase
      def setup
        @user = users(:one)
        @prompt_template = PromptTemplate.create!(
          name: 'Test Template',
          prompt_body: 'Hello {{name}}!',
          output_format: 'text',
          created_by: @user
        )
        @execution = PromptExecution.create!(
          prompt_template: @prompt_template,
          user: @user,
          input_context: { name: 'John' },
          rendered_prompt: 'Hello John!',
          status: 'pending'
        )
      end

      test 'should be valid with required attributes' do
        execution = PromptExecution.new(
          prompt_template: @prompt_template,
          input_context: { test: 'value' },
          rendered_prompt: 'Test prompt',
          status: 'pending'
        )
        assert execution.valid?
      end

      test 'should require prompt_template' do
        execution = PromptExecution.new(
          input_context: { test: 'value' },
          rendered_prompt: 'Test',
          status: 'pending'
        )
        assert_not execution.valid?
        assert_includes execution.errors[:prompt_template], "must exist"
      end

      test 'should require input_context' do
        execution = PromptExecution.new(
          prompt_template: @prompt_template,
          rendered_prompt: 'Test',
          status: 'pending'
        )
        assert_not execution.valid?
        assert_includes execution.errors[:input_context], "can't be blank"
      end

      test 'should require valid status' do
        execution = PromptExecution.new(
          prompt_template: @prompt_template,
          input_context: { test: 'value' },
          rendered_prompt: 'Test',
          status: 'invalid_status'
        )
        assert_not execution.valid?
        assert_includes execution.errors[:status], 'is not included in the list'
      end

      test 'should identify successful executions' do
        @execution.update!(status: 'completed')
        assert @execution.success?
        assert_not @execution.failed?
      end

      test 'should identify failed executions' do
        @execution.update!(status: 'failed')
        assert @execution.failed?
        assert_not @execution.success?
      end

      test 'should calculate duration when both timestamps exist' do
        start_time = Time.current
        end_time = start_time + 5.seconds
        
        @execution.update!(started_at: start_time, completed_at: end_time)
        assert_equal 5.0, @execution.duration
      end

      test 'should return nil duration when timestamps missing' do
        assert_nil @execution.duration
      end

      test 'should scope successful executions' do
        successful = PromptExecution.create!(
          prompt_template: @prompt_template,
          input_context: { test: 'value' },
          rendered_prompt: 'Test',
          status: 'completed'
        )
        
        results = PromptExecution.successful
        assert_includes results, successful
        assert_not_includes results, @execution
      end

      test 'should scope failed executions' do
        failed = PromptExecution.create!(
          prompt_template: @prompt_template,
          input_context: { test: 'value' },
          rendered_prompt: 'Test',
          status: 'failed'
        )
        
        results = PromptExecution.failed
        assert_includes results, failed
        assert_not_includes results, @execution
      end

      test 'should order by created_at desc for recent scope' do
        older = PromptExecution.create!(
          prompt_template: @prompt_template,
          input_context: { test: 'old' },
          rendered_prompt: 'Old',
          status: 'completed',
          created_at: 1.hour.ago
        )
        
        newer = PromptExecution.create!(
          prompt_template: @prompt_template,
          input_context: { test: 'new' },
          rendered_prompt: 'New',
          status: 'completed'
        )

        recent = PromptExecution.recent
        assert_equal newer, recent.first
        assert_equal older, recent.last
      end
    end
  RUBY

  # Controller tests
  create_file 'test/controllers/prompt_templates_controller_test.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'test_helper'

    class PromptTemplatesControllerTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:one)
        sign_in @user # Assumes Devise test helpers
        
        @prompt_template = PromptTemplate.create!(
          name: 'Test Template',
          prompt_body: 'Hello {{name}}!',
          output_format: 'text',
          created_by: @user
        )
      end

      test 'should get index' do
        get prompt_templates_url
        assert_response :success
        assert_select 'h1', 'Prompt Templates'
      end

      test 'should filter by tag' do
        tagged_template = PromptTemplate.create!(
          name: 'Tagged Template',
          prompt_body: 'Test',
          output_format: 'text',
          tags: ['important']
        )

        get prompt_templates_url, params: { tag: 'important' }
        assert_response :success
        assert_match tagged_template.name, response.body
      end

      test 'should filter by output format' do
        json_template = PromptTemplate.create!(
          name: 'JSON Template',
          prompt_body: 'Test',
          output_format: 'json'
        )

        get prompt_templates_url, params: { output_format: 'json' }
        assert_response :success
        assert_match json_template.name, response.body
      end

      test 'should show prompt template' do
        get prompt_template_url(@prompt_template)
        assert_response :success
        assert_select 'h2', @prompt_template.name
      end

      test 'should get new' do
        get new_prompt_template_url
        assert_response :success
        assert_select 'h1', 'New Prompt Template'
      end

      test 'should create prompt template' do
        assert_difference 'PromptTemplate.count', 1 do
          post prompt_templates_url, params: {
            prompt_template: {
              name: 'New Template',
              prompt_body: 'Test prompt with {{variable}}',
              output_format: 'text',
              description: 'Test description',
              tags: ['test']
            }
          }
        end

        template = PromptTemplate.last
        assert_equal @user, template.created_by
        assert_redirected_to prompt_template_path(template)
      end

      test 'should not create invalid prompt template' do
        assert_no_difference 'PromptTemplate.count' do
          post prompt_templates_url, params: {
            prompt_template: {
              name: '', # Invalid - blank name
              prompt_body: 'Test',
              output_format: 'text'
            }
          }
        end

        assert_response :unprocessable_entity
      end

      test 'should get edit' do
        get edit_prompt_template_url(@prompt_template)
        assert_response :success
        assert_select 'h1', 'Edit Prompt Template'
      end

      test 'should update prompt template' do
        patch prompt_template_url(@prompt_template), params: {
          prompt_template: {
            name: 'Updated Template'
          }
        }

        @prompt_template.reload
        assert_equal 'Updated Template', @prompt_template.name
        assert_redirected_to prompt_template_path(@prompt_template)
      end

      test 'should not update with invalid data' do
        patch prompt_template_url(@prompt_template), params: {
          prompt_template: {
            name: '' # Invalid
          }
        }

        assert_response :unprocessable_entity
        @prompt_template.reload
        assert_not_equal '', @prompt_template.name
      end

      test 'should destroy prompt template' do
        assert_difference 'PromptTemplate.count', -1 do
          delete prompt_template_url(@prompt_template)
        end

        assert_redirected_to prompt_templates_path
      end

      test 'should preview prompt template' do
        post preview_prompt_template_url(@prompt_template), params: {
          context: '{"name": "John"}'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_equal 'Hello John!', response_data['rendered_prompt']
        assert_nil response_data['validation_errors']
      end

      test 'should preview with missing variables' do
        post preview_prompt_template_url(@prompt_template), params: {
          context: '{}'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_equal ['name'], response_data['validation_errors']
      end

      test 'should handle invalid JSON in preview' do
        post preview_prompt_template_url(@prompt_template), params: {
          context: 'invalid json'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_includes response_data['validation_errors'], 'Invalid JSON in context'
      end

      test 'should show diff between versions' do
        # Create a version by updating the template
        @prompt_template.update!(name: 'Updated Name')
        version = @prompt_template.versions.last

        get diff_prompt_template_url(@prompt_template), params: {
          version_id: version.id
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_equal 'Test Template', response_data['previous']['name']
        assert_equal 'Updated Name', response_data['current']['name']
      end

      test 'should handle invalid version in diff' do
        get diff_prompt_template_url(@prompt_template), params: {
          version_id: 99999
        }, as: :json

        assert_response :not_found
        response_data = JSON.parse(response.body)
        assert_equal 'Version not found', response_data['error']
      end
    end
  RUBY

  create_file 'test/controllers/prompt_executions_controller_test.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'test_helper'

    class PromptExecutionsControllerTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:one)
        sign_in @user
        
        @prompt_template = PromptTemplate.create!(
          name: 'Test Template',
          prompt_body: 'Hello {{name}}!',
          output_format: 'text',
          created_by: @user
        )
        
        @execution = PromptExecution.create!(
          prompt_template: @prompt_template,
          user: @user,
          input_context: { name: 'John' },
          rendered_prompt: 'Hello John!',
          status: 'completed'
        )
      end

      test 'should get index' do
        get prompt_template_prompt_executions_url(@prompt_template)
        assert_response :success
        assert_match @prompt_template.name, response.body
      end

      test 'should filter by status' do
        failed_execution = PromptExecution.create!(
          prompt_template: @prompt_template,
          user: @user,
          input_context: { name: 'Jane' },
          rendered_prompt: 'Hello Jane!',
          status: 'failed'
        )

        get prompt_template_prompt_executions_url(@prompt_template), params: {
          status: 'failed'
        }
        
        assert_response :success
        assert_match 'Failed', response.body
      end

      test 'should show execution' do
        get prompt_template_prompt_execution_url(@prompt_template, @execution)
        assert_response :success
        assert_match 'Execution Details', response.body
      end

      test 'should create execution with valid context' do
        assert_difference 'PromptExecution.count', 1 do
          post prompt_template_prompt_executions_url(@prompt_template), params: {
            context: '{"name": "Alice"}'
          }, as: :json
        end

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_includes response_data['message'], 'queued successfully'
        
        execution = PromptExecution.last
        assert_equal @user, execution.user
        assert_equal({ 'name' => 'Alice' }, execution.input_context)
        assert_equal 'Hello Alice!', execution.rendered_prompt
      end

      test 'should not create execution with missing variables' do
        assert_no_difference 'PromptExecution.count' do
          post prompt_template_prompt_executions_url(@prompt_template), params: {
            context: '{}'
          }, as: :json
        end

        assert_response :unprocessable_entity
        response_data = JSON.parse(response.body)
        assert_includes response_data['error'], 'Missing required variables: name'
      end

      test 'should not create execution with invalid JSON' do
        assert_no_difference 'PromptExecution.count' do
          post prompt_template_prompt_executions_url(@prompt_template), params: {
            context: 'invalid json'
          }, as: :json
        end

        assert_response :unprocessable_entity
        response_data = JSON.parse(response.body)
        assert_equal 'Invalid JSON in context', response_data['error']
      end

      test 'should destroy execution' do
        assert_difference 'PromptExecution.count', -1 do
          delete prompt_template_prompt_execution_url(@prompt_template, @execution)
        end

        assert_redirected_to prompt_template_path(@prompt_template)
      end
    end
  RUBY

  # Fixtures
  create_file 'test/fixtures/prompt_templates.yml', <<~'YAML'
    basic:
      name: Basic Template
      slug: basic_template
      prompt_body: Hello {{name}}!
      output_format: text
      active: true
      created_at: <%= 1.day.ago %>
      updated_at: <%= 1.day.ago %>

    json_template:
      name: JSON Template
      slug: json_template
      prompt_body: Generate JSON for {{entity}}
      output_format: json
      tags: [api, structured]
      active: true
      created_at: <%= 2.days.ago %>
      updated_at: <%= 2.days.ago %>

    inactive:
      name: Inactive Template
      slug: inactive_template
      prompt_body: This template is not active
      output_format: text
      active: false
      created_at: <%= 3.days.ago %>
      updated_at: <%= 3.days.ago %>
  YAML

  create_file 'test/fixtures/prompt_executions.yml', <<~'YAML'
    successful:
      prompt_template: basic
      input_context: {"name": "John"}
      rendered_prompt: Hello John!
      output: Hello John! How can I help you today?
      status: completed
      started_at: <%= 1.hour.ago %>
      completed_at: <%= 55.minutes.ago %>
      created_at: <%= 1.hour.ago %>
      updated_at: <%= 55.minutes.ago %>

    failed:
      prompt_template: json_template
      input_context: {"entity": "user"}
      rendered_prompt: Generate JSON for user
      error_message: API rate limit exceeded
      status: failed
      started_at: <%= 30.minutes.ago %>
      completed_at: <%= 25.minutes.ago %>
      created_at: <%= 30.minutes.ago %>
      updated_at: <%= 25.minutes.ago %>

    pending:
      prompt_template: basic
      input_context: {"name": "Alice"}
      rendered_prompt: Hello Alice!
      status: pending
      created_at: <%= 5.minutes.ago %>
      updated_at: <%= 5.minutes.ago %>
  YAML

  # Create seed data
  create_file 'db/seeds/prompt_templates.rb', <<~'RUBY'
    # frozen_string_literal: true

    # Create example prompt templates for demonstration and testing
    puts "Creating example prompt templates..."

    # Basic greeting template
    PromptTemplate.find_or_create_by(slug: 'welcome_email') do |template|
      template.name = 'Welcome Email'
      template.description = 'Generate a personalized welcome email for new users'
      template.prompt_body = <<~PROMPT.strip
        Write a warm and professional welcome email for a new user.
        
        User Details:
        - Name: {{user_name}}
        - Email: {{user_email}}
        - Company: {{company_name}}
        - Plan: {{subscription_plan}}
        
        The email should:
        1. Welcome them personally
        2. Mention their subscription plan
        3. Provide helpful next steps
        4. Include a call-to-action to get started
        
        Keep the tone friendly but professional.
      PROMPT
      template.output_format = 'markdown'
      template.tags = ['email', 'onboarding', 'customer']
      template.active = true
    end

    # Customer support response template
    PromptTemplate.find_or_create_by(slug: 'support_response') do |template|
      template.name = 'Customer Support Response'
      template.description = 'Generate empathetic and helpful customer support responses'
      template.prompt_body = <<~PROMPT.strip
        You are a helpful customer support representative. Respond to the customer's inquiry below.
        
        Customer Information:
        - Name: {{customer_name}}
        - Account Type: {{account_type}}
        - Issue Category: {{issue_category}}
        
        Customer Message:
        {{customer_message}}
        
        Provide a helpful, empathetic response that:
        1. Acknowledges their concern
        2. Provides a clear solution or next steps
        3. Offers additional assistance if needed
        4. Maintains a professional but warm tone
        
        If you need additional information to help resolve their issue, ask specific questions.
      PROMPT
      template.output_format = 'text'
      template.tags = ['support', 'customer', 'communication']
      template.active = true
    end

    # Product description generator
    PromptTemplate.find_or_create_by(slug: 'product_description') do |template|
      template.name = 'Product Description Generator'
      template.description = 'Create compelling product descriptions for e-commerce'
      template.prompt_body = <<~PROMPT.strip
        Create a compelling product description for an e-commerce listing.
        
        Product Details:
        - Name: {{product_name}}
        - Category: {{product_category}}
        - Key Features: {{key_features}}
        - Target Audience: {{target_audience}}
        - Price Range: {{price_range}}
        - Brand: {{brand}}
        
        Create a description that:
        1. Highlights the main benefits
        2. Appeals to the target audience
        3. Uses persuasive but accurate language
        4. Is optimized for search engines
        5. Includes a compelling call-to-action
        
        Format the output with clear sections for features, benefits, and specifications.
      PROMPT
      template.output_format = 'html_partial'
      template.tags = ['ecommerce', 'marketing', 'product']
      template.active = true
    end

    # API documentation generator
    PromptTemplate.find_or_create_by(slug: 'api_docs') do |template|
      template.name = 'API Documentation Generator'
      template.description = 'Generate comprehensive API endpoint documentation'
      template.prompt_body = <<~PROMPT.strip
        Generate comprehensive documentation for an API endpoint.
        
        Endpoint Details:
        - Method: {{http_method}}
        - Path: {{endpoint_path}}
        - Description: {{endpoint_description}}
        - Parameters: {{parameters}}
        - Response Format: {{response_format}}
        - Example Use Case: {{use_case}}
        
        Create documentation that includes:
        1. Clear endpoint description
        2. Request/response examples
        3. Parameter descriptions with types and requirements
        4. Error response examples
        5. Code examples in popular languages
        
        Use clear, technical language appropriate for developers.
      PROMPT
      template.output_format = 'markdown'
      template.tags = ['documentation', 'api', 'technical']
      template.active = true
    end

    # Meeting summary template
    PromptTemplate.find_or_create_by(slug: 'meeting_summary') do |template|
      template.name = 'Meeting Summary Generator'
      template.description = 'Create structured summaries from meeting transcripts'
      template.prompt_body = <<~PROMPT.strip
        Create a comprehensive meeting summary from the provided transcript.
        
        Meeting Details:
        - Date: {{meeting_date}}
        - Attendees: {{attendees}}
        - Duration: {{duration}}
        - Meeting Type: {{meeting_type}}
        
        Transcript:
        {{transcript}}
        
        Create a summary with the following sections:
        1. **Key Decisions Made**
        2. **Action Items** (with assigned owners and due dates)
        3. **Discussion Points**
        4. **Next Steps**
        5. **Follow-up Required**
        
        Be concise but comprehensive, and ensure all important points are captured.
      PROMPT
      template.output_format = 'markdown'
      template.tags = ['productivity', 'meeting', 'summary']
      template.active = true
    end

    # Data analysis insights
    PromptTemplate.find_or_create_by(slug: 'data_insights') do |template|
      template.name = 'Data Analysis Insights'
      template.description = 'Generate insights and recommendations from data analysis'
      template.prompt_body = <<~PROMPT.strip
        Analyze the provided data and generate actionable insights.
        
        Analysis Context:
        - Data Type: {{data_type}}
        - Time Period: {{time_period}}
        - Business Context: {{business_context}}
        - Key Metrics: {{key_metrics}}
        
        Data Summary:
        {{data_summary}}
        
        Provide analysis in JSON format with the following structure:
        {
          "key_findings": ["finding 1", "finding 2"],
          "trends": ["trend 1", "trend 2"],
          "recommendations": [
            {
              "action": "specific action",
              "priority": "high|medium|low",
              "impact": "expected impact",
              "timeline": "suggested timeline"
            }
          ],
          "risks": ["risk 1", "risk 2"],
          "opportunities": ["opportunity 1", "opportunity 2"]
        }
        
        Focus on actionable insights that drive business value.
      PROMPT
      template.output_format = 'json'
      template.tags = ['analytics', 'business', 'insights', 'data']
      template.active = true
    end

    puts "Created #{PromptTemplate.count} example prompt templates"

    # Create some example executions for demonstration
    if PromptTemplate.exists?
      puts "Creating example prompt executions..."
      
      welcome_template = PromptTemplate.find_by(slug: 'welcome_email')
      if welcome_template
        PromptExecution.find_or_create_by(
          prompt_template: welcome_template,
          input_context: {
            user_name: "John Doe",
            user_email: "john@example.com", 
            company_name: "Acme Corp",
            subscription_plan: "Pro"
          }
        ) do |execution|
          execution.rendered_prompt = welcome_template.render_with_context(execution.input_context)
          execution.status = 'completed'
          execution.output = <<~EMAIL.strip
            Subject: Welcome to Our Platform, John!

            Hi John,

            Welcome to our platform! We're thrilled to have Acme Corp join our community of innovative companies.

            Your Pro subscription is now active and ready to use. Here's what you can do next:

            1. **Complete your profile** - Add your team members and set up your workspace
            2. **Explore features** - Check out our advanced analytics and reporting tools
            3. **Schedule a demo** - Our team can show you Pro features that will save you time

            Ready to get started? [Set Up Your Workspace →]

            If you have any questions, our support team is here to help at support@example.com.

            Best regards,
            The Team
          EMAIL
          execution.started_at = 1.hour.ago
          execution.completed_at = 1.hour.ago + 3.seconds
          execution.model_used = 'gpt-4'
          execution.tokens_used = 245
        end
      end

      puts "Created example prompt executions"
    end
  RUBY

  # Update the main seeds file to include prompt template seeds
  append_to_file 'db/seeds.rb', <<~'RUBY'
    
    # Load AI module seeds
    load Rails.root.join('db', 'seeds', 'prompt_templates.rb') if File.exist?(Rails.root.join('db', 'seeds', 'prompt_templates.rb'))
  RUBY

  # Create LLM job for executing prompt templates
  create_file 'app/jobs/llm_job.rb', <<~'RUBY'
    # frozen_string_literal: true

    class LLMJob < ApplicationJob
      queue_as :default
      
      retry_on StandardError, wait: :exponentially_longer, attempts: 3

      def perform(execution_id)
        execution = PromptExecution.find(execution_id)
        
        execution.update!(
          status: 'processing',
          started_at: Time.current
        )

        begin
          # Call LLM API - this is a placeholder implementation
          # In a real application, you would integrate with OpenAI, Claude, etc.
          response = call_llm_api(
            prompt: execution.rendered_prompt,
            format: execution.prompt_template.output_format,
            temperature: Rails.application.config.ai.default_temperature
          )
          
          execution.update!(
            status: 'completed',
            output: response[:content],
            completed_at: Time.current,
            model_used: response[:model],
            tokens_used: response[:tokens_used]
          )
        rescue => error
          execution.update!(
            status: 'failed',
            error_message: error.message,
            completed_at: Time.current
          )
          raise error
        end
      end

      private

      def call_llm_api(prompt:, format:, temperature:)
        # Placeholder implementation - replace with actual LLM API calls
        # Example for OpenAI:
        # 
        # client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
        # response = client.completions(
        #   parameters: {
        #     model: Rails.application.config.ai.default_model,
        #     prompt: prompt,
        #     temperature: temperature,
        #     max_tokens: Rails.application.config.ai.max_tokens
        #   }
        # )
        # 
        # {
        #   content: response['choices'][0]['text'],
        #   model: Rails.application.config.ai.default_model,
        #   tokens_used: response['usage']['total_tokens']
        # }

        # Simulated response for demonstration
        simulated_content = case format
        when 'json'
          '{"result": "This is a simulated JSON response based on the prompt"}'
        when 'markdown'
          "# Simulated Response\n\nThis is a **simulated** markdown response based on your prompt:\n\n> #{prompt.truncate(100)}"
        when 'html_partial'
          "<div class='generated-content'><h3>Generated Content</h3><p>This is simulated HTML content.</p></div>"
        else
          "This is a simulated text response based on your prompt. In a real implementation, this would be generated by an LLM API."
        end

        {
          content: simulated_content,
          model: Rails.application.config.ai.default_model,
          tokens_used: rand(50..300)
        }
      end
    end
  RUBY

  # Create a service for executing prompt templates
  create_file 'app/services/prompt_executor.rb', <<~'RUBY'
    # frozen_string_literal: true

    class PromptExecutor
      def self.execute_async(template:, context:, user: nil)
        # Validate context
        missing_vars = template.validate_context(context)
        if missing_vars != true
          raise ArgumentError, "Missing required variables: #{missing_vars.join(', ')}"
        end

        # Create execution record
        execution = PromptExecution.create!(
          prompt_template: template,
          user: user,
          workspace: template.workspace,
          input_context: context,
          rendered_prompt: template.render_with_context(context),
          status: 'pending'
        )

        # Queue LLM job
        LLMJob.perform_later(execution.id)
        
        execution
      end

      def self.execute_sync(template:, context:, user: nil)
        execution = execute_async(template: template, context: context, user: user)
        
        # Process immediately in foreground (for testing/development)
        LLMJob.new.perform(execution.id)
        
        execution.reload
      end
    end
  RUBY

  # Update the PromptExecutionsController to use the new service
  gsub_file 'app/controllers/prompt_executions_controller.rb', 
    /# TODO: Enqueue LLM job to process the execution/,
    'PromptExecutor.execute_async(template: @prompt_template, context: context, user: current_user)'

  # Create API endpoints for programmatic access
  create_file 'app/controllers/api/v1/prompt_templates_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Api::V1::PromptTemplatesController < ApplicationController
      before_action :authenticate_user! # Adjust based on your API authentication
      before_action :set_prompt_template, only: [:show, :execute]

      def index
        @templates = PromptTemplate.where(active: true)
        @templates = @templates.by_tag(params[:tag]) if params[:tag].present?
        @templates = @templates.by_output_format(params[:output_format]) if params[:output_format].present?
        
        render json: @templates.map { |t| template_summary(t) }
      end

      def show
        render json: template_detail(@prompt_template)
      end

      def execute
        context = params[:context] || {}
        
        begin
          execution = PromptExecutor.execute_async(
            template: @prompt_template,
            context: context,
            user: current_user
          )
          
          render json: {
            execution_id: execution.id,
            status: execution.status,
            message: 'Execution queued successfully'
          }, status: :created
        rescue ArgumentError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      private

      def set_prompt_template
        @prompt_template = PromptTemplate.find_by!(slug: params[:slug])
      end

      def template_summary(template)
        {
          id: template.id,
          name: template.name,
          slug: template.slug,
          description: template.description,
          output_format: template.output_format,
          tags: template.tags,
          variable_names: template.variable_names,
          created_at: template.created_at,
          updated_at: template.updated_at
        }
      end

      def template_detail(template)
        template_summary(template).merge(
          prompt_body: template.prompt_body,
          execution_count: template.prompt_executions.count,
          recent_executions: template.prompt_executions.recent.limit(5).map do |execution|
            {
              id: execution.id,
              status: execution.status,
              created_at: execution.created_at,
              duration: execution.duration
            }
          end
        )
      end
    end
  RUBY

  create_file 'app/controllers/api/v1/prompt_executions_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Api::V1::PromptExecutionsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_execution, only: [:show]

      def show
        render json: execution_detail(@execution)
      end

      private

      def set_execution
        @execution = PromptExecution.find(params[:id])
        # Add authorization check here if needed
      end

      def execution_detail(execution)
        {
          id: execution.id,
          prompt_template: {
            id: execution.prompt_template.id,
            name: execution.prompt_template.name,
            slug: execution.prompt_template.slug
          },
          status: execution.status,
          input_context: execution.input_context,
          rendered_prompt: execution.rendered_prompt,
          output: execution.output,
          error_message: execution.error_message,
          model_used: execution.model_used,
          tokens_used: execution.tokens_used,
          duration: execution.duration,
          created_at: execution.created_at,
          started_at: execution.started_at,
          completed_at: execution.completed_at,
          user: execution.user ? { id: execution.user.id, email: execution.user.email } : nil
        }
      end
    end
  RUBY

  # Add API routes
  route <<~'RUBY'
    namespace :api do
      namespace :v1 do
        resources :prompt_templates, param: :slug, only: [:index, :show] do
          member do
            post :execute
          end
        end
        resources :prompt_executions, only: [:show]
      end
    end
  RUBY

  # Add integration test for the complete workflow
  create_file 'test/integration/prompt_template_workflow_test.rb', <<~'RUBY'
    # frozen_string_literal: true

    require 'test_helper'

    class PromptTemplateWorkflowTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:one)
        sign_in @user
      end

      test 'complete prompt template lifecycle' do
        # 1. Create a new template
        get new_prompt_template_path
        assert_response :success

        post prompt_templates_path, params: {
          prompt_template: {
            name: 'Integration Test Template',
            description: 'A template for testing the complete workflow',
            prompt_body: 'Hello {{name}}, your order {{order_id}} is {{status}}.',
            output_format: 'text',
            tags: ['integration', 'test']
          }
        }

        template = PromptTemplate.last
        assert_redirected_to prompt_template_path(template)
        
        # 2. View the template
        follow_redirect!
        assert_response :success
        assert_select 'h2', template.name

        # 3. Preview the template
        post preview_prompt_template_path(template), params: {
          context: '{"name": "John", "order_id": "12345", "status": "confirmed"}'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_equal 'Hello John, your order 12345 is confirmed.', response_data['rendered_prompt']

        # 4. Execute the template
        assert_difference 'PromptExecution.count', 1 do
          post prompt_template_prompt_executions_path(template), params: {
            context: '{"name": "Alice", "order_id": "67890", "status": "shipped"}'
          }, as: :json
        end

        assert_response :success
        execution = PromptExecution.last
        assert_equal template, execution.prompt_template
        assert_equal @user, execution.user
        assert_equal 'Hello Alice, your order 67890 is shipped.', execution.rendered_prompt

        # 5. View execution details
        get prompt_template_prompt_execution_path(template, execution)
        assert_response :success
        assert_select 'h1', 'Execution Details'

        # 6. Update template to create a new version
        patch prompt_template_path(template), params: {
          prompt_template: {
            name: 'Updated Integration Test Template',
            prompt_body: 'Hi {{name}}, your order {{order_id}} status: {{status}}!'
          }
        }

        template.reload
        assert_equal 'Updated Integration Test Template', template.name
        assert_equal 1, template.versions.count

        # 7. View diff between versions
        version = template.versions.first
        get diff_prompt_template_path(template), params: { version_id: version.id }, as: :json
        
        assert_response :success
        diff_data = JSON.parse(response.body)
        assert_equal 'Integration Test Template', diff_data['previous']['name']
        assert_equal 'Updated Integration Test Template', diff_data['current']['name']

        # 8. View executions list
        get prompt_template_prompt_executions_path(template)
        assert_response :success
        assert_match execution.user.email, response.body
      end

      test 'API workflow' do
        template = PromptTemplate.create!(
          name: 'API Test Template',
          slug: 'api_test',
          prompt_body: 'API test for {{user}} with {{data}}',
          output_format: 'json',
          active: true
        )

        # 1. List templates via API
        get api_v1_prompt_templates_path, as: :json
        assert_response :success
        
        templates = JSON.parse(response.body)
        api_template = templates.find { |t| t['slug'] == 'api_test' }
        assert_not_nil api_template
        assert_equal 'API Test Template', api_template['name']

        # 2. Get template details via API
        get api_v1_prompt_template_path('api_test'), as: :json
        assert_response :success
        
        template_data = JSON.parse(response.body)
        assert_equal 'API Test Template', template_data['name']
        assert_equal ['user', 'data'], template_data['variable_names']

        # 3. Execute template via API
        post execute_api_v1_prompt_template_path('api_test'), params: {
          context: { user: 'john', data: 'sample data' }
        }, as: :json

        assert_response :created
        result = JSON.parse(response.body)
        assert_includes result['message'], 'queued successfully'

        # 4. Check execution via API
        execution_id = result['execution_id']
        get api_v1_prompt_execution_path(execution_id), as: :json
        
        assert_response :success
        execution_data = JSON.parse(response.body)
        assert_equal 'API test for john with sample data', execution_data['rendered_prompt']
      end

      test 'error handling and validation' do
        template = PromptTemplate.create!(
          name: 'Validation Test',
          prompt_body: 'Required: {{required_var}}',
          output_format: 'text',
          active: true
        )

        # Test missing variables in preview
        post preview_prompt_template_path(template), params: {
          context: '{}'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_equal ['required_var'], response_data['validation_errors']

        # Test missing variables in execution
        post prompt_template_prompt_executions_path(template), params: {
          context: '{}'
        }, as: :json

        assert_response :unprocessable_entity
        error_data = JSON.parse(response.body)
        assert_includes error_data['error'], 'Missing required variables'

        # Test invalid JSON
        post preview_prompt_template_path(template), params: {
          context: 'invalid json'
        }, as: :json

        assert_response :success
        response_data = JSON.parse(response.body)
        assert_includes response_data['validation_errors'], 'Invalid JSON in context'
      end
    end
  RUBY

  say_status :synth_ai, "Generated comprehensive integration test for complete workflow"
  say_status :synth_ai, "AI module with PromptTemplate system fully implemented!"
  say_status :synth_ai, ""
  say_status :synth_ai, "Next steps after installation:"
  say_status :synth_ai, "1. Run 'rails db:migrate' to create database tables"
  say_status :synth_ai, "2. Run 'rails db:seed' to create example templates"
  say_status :synth_ai, "3. Configure LLM API keys in Rails credentials"
  say_status :synth_ai, "4. Visit /prompt_templates to start using the interface"
  say_status :synth_ai, "5. Run 'rails test' to verify everything works"
end
