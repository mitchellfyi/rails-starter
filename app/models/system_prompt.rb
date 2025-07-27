# frozen_string_literal: true

class SystemPrompt < ApplicationRecord
  has_paper_trail

  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  validates :slug, presence: true, uniqueness: { scope: :workspace_id }, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :prompt_text, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft active archived] }
  validates :version, presence: true, format: { with: /\A\d+\.\d+\.\d+\z/ }

  belongs_to :workspace, optional: true # null workspace means global
  belongs_to :created_by, class_name: 'User', optional: true
  
  # For associating with roles, templates, or agents
  serialize :associated_roles, Array
  serialize :associated_functions, Array
  serialize :associated_agents, Array

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :set_initial_version, if: -> { version.blank? }

  scope :active, -> { where(status: 'active') }
  scope :global, -> { where(workspace: nil) }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) }
  scope :by_role, ->(role) { where('? = ANY(associated_roles)', role) }
  scope :by_function, ->(function) { where('? = ANY(associated_functions)', function) }
  scope :by_agent, ->(agent) { where('? = ANY(associated_agents)', agent) }

  # Find the best system prompt for a workspace with fallback to global
  def self.find_for_workspace(workspace, role: nil, function: nil, agent: nil)
    # First try workspace-specific prompts
    if workspace
      prompt = for_workspace(workspace).active
      prompt = prompt.by_role(role) if role
      prompt = prompt.by_function(function) if function
      prompt = prompt.by_agent(agent) if agent
      return prompt.order(created_at: :desc).first if prompt.exists?
    end

    # Fallback to global prompts
    prompt = global.active
    prompt = prompt.by_role(role) if role
    prompt = prompt.by_function(function) if function
    prompt = prompt.by_agent(agent) if agent
    prompt.order(created_at: :desc).first
  end

  # Extract variable names from prompt text (e.g., {{user_name}}, {{company}})
  def variable_names
    prompt_text.scan(/\{\{(\w+)\}\}/).flatten.uniq
  end

  # Render the prompt with provided context variables
  def render_with_context(context = {})
    rendered = prompt_text.dup
    
    variable_names.each do |var_name|
      value = context[var_name] || context[var_name.to_sym] || ""
      rendered.gsub!("{{#{var_name}}}", value.to_s)
    end
    
    rendered
  end

  # Get all versions of this prompt (by name within workspace)
  def version_history
    self.class.where(workspace: workspace, name: name).order(:created_at)
  end

  # Check if this is the latest version
  def latest_version?
    return true if version_history.count <= 1
    
    version_history.maximum(:created_at) == created_at
  end

  # Create a new version (copy) of this prompt
  def create_new_version!(new_attributes = {})
    new_version_number = increment_version_number
    
    new_prompt = self.class.create!(
      attributes.except('id', 'created_at', 'updated_at', 'slug')
        .merge(new_attributes)
        .merge(
          version: new_version_number,
          slug: generate_versioned_slug(new_version_number),
          status: 'draft' # New versions start as draft
        )
    )
    
    new_prompt
  end

  # Activate this version (makes it the active version)
  def activate!
    transaction do
      # Deactivate other versions of the same prompt
      version_history.where.not(id: id).update_all(status: 'archived')
      
      # Activate this version
      update!(status: 'active')
    end
  end

  # Clone this prompt for editing
  def clone!(new_name = nil, target_workspace = nil)
    cloned_name = new_name || "#{name} (Copy)"
    
    self.class.create!(
      attributes.except('id', 'created_at', 'updated_at', 'slug', 'name', 'workspace_id')
        .merge(
          name: cloned_name,
          workspace: target_workspace || workspace,
          version: '1.0.0',
          status: 'draft'
        )
    )
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
        prompt_text: previous.prompt_text,
        description: previous.description,
        status: previous.status,
        associated_roles: previous.associated_roles,
        associated_functions: previous.associated_functions,
        associated_agents: previous.associated_agents,
        version: previous.version
      },
      current: {
        name: name,
        prompt_text: prompt_text,
        description: description,
        status: status,
        associated_roles: associated_roles,
        associated_functions: associated_functions,
        associated_agents: associated_agents,
        version: version
      },
      changes: changes_from_version(previous)
    }
  end

  # Check if this prompt is global (not workspace-specific)
  def global?
    workspace_id.nil?
  end

  # Get display name with workspace context
  def display_name
    if global?
      "#{name} (Global)"
    else
      "#{name} (#{workspace.name})"
    end
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
    
    %w[name prompt_text description status associated_roles associated_functions associated_agents].each do |field|
      current_value = send(field)
      previous_value = previous.send(field)
      
      if current_value != previous_value
        changes[field] = [previous_value, current_value]
      end
    end
    
    changes
  end
end