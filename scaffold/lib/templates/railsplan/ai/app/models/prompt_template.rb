# frozen_string_literal: true

class PromptTemplate < ApplicationRecord
  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :slug, presence: true, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :prompt_body, presence: true
  validates :output_format, presence: true, inclusion: { in: %w[text json markdown html] }
  validates :version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/ }

  belongs_to :workspace, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :prompt_executions, dependent: :destroy
  has_many :llm_outputs, foreign_key: :template_name, primary_key: :slug, dependent: :nullify

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :set_initial_version, if: -> { version.blank? }

  scope :active, -> { where(active: true) }
  scope :published, -> { where(published: true) }
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

  # Get all versions of this template (by name within workspace)
  def version_history
    self.class.where(workspace: workspace, name: name).order(:created_at)
  end

  # Check if this is the latest version
  def latest_version?
    return true if version_history.count <= 1
    
    version_history.maximum(:created_at) == created_at
  end

  # Get the previous version
  def previous_version
    return nil unless versions.exists?
    
    last_version = versions.order(:created_at).last
    last_version&.reify
  end

  # Create a new version (copy) of this template
  def create_new_version!(new_attributes = {})
    new_version_number = increment_version_number
    
    new_template = self.class.create!(
      attributes.except('id', 'created_at', 'updated_at', 'slug')
        .merge(new_attributes)
        .merge(
          version: new_version_number,
          slug: generate_versioned_slug(new_version_number),
          published: false # New versions start unpublished
        )
    )
    
    new_template
  end

  # Publish this version (makes it the active version)
  def publish!
    transaction do
      # Unpublish other versions of the same template
      version_history.where.not(id: id).update_all(published: false, active: false)
      
      # Publish this version
      update!(published: true, active: true)
    end
  end

  # Get differences compared to a specific version
  def diff_with_version(version_id)
    version = versions.find_by(id: version_id)
    return nil unless version

    previous = version.reify
    return nil unless previous

    {
      previous: {
        name: previous.name,
        prompt_body: previous.prompt_body,
        description: previous.description,
        output_format: previous.output_format,
        tags: previous.tags,
        version: previous.version
      },
      current: {
        name: name,
        prompt_body: prompt_body,
        description: description,
        output_format: output_format,
        tags: tags,
        version: version
      },
      changes: changes_from_version(previous)
    }
  end

  # Create a test execution for preview purposes
  def create_preview_execution(context, user = nil)
    missing_vars = validate_context(context)
    if missing_vars != true
      raise ArgumentError, "Missing required variables: #{missing_vars.join(', ')}"
    end

    PromptExecution.create!(
      prompt_template: self,
      user: user,
      workspace: workspace,
      input_context: context,
      rendered_prompt: render_with_context(context),
      status: 'preview'
    )
  end

  private

  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
  end

  def set_initial_version
    self.version = '1.0.0'
  end

  def increment_version_number
    current_parts = version.split('.').map(&:to_i)
    current_parts[2] += 1 # Increment patch version
    current_parts.join('.')
  end

  def generate_versioned_slug(version_num)
    base_slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
    "#{base_slug}_v#{version_num.gsub('.', '_')}"
  end

  def changes_from_version(previous)
    changes = {}
    
    %w[name prompt_body description output_format tags].each do |field|
      current_value = send(field)
      previous_value = previous.send(field)
      
      if current_value != previous_value
        changes[field] = [previous_value, current_value]
      end
    end
    
    changes
  end
end