# frozen_string_literal: true

class AiProvider < ApplicationRecord
  has_many :ai_credentials, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :api_base_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  
  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(:priority, :name) }
  
  # Check if provider supports a specific model
  def supports_model?(model_name)
    supported_models.include?(model_name.to_s)
  end
  
  # Get default configuration for this provider
  def config_for_model(model_name)
    default_config.merge(model: model_name)
  end
  
  # Test if provider is accessible (ping test)
  def test_connectivity(api_key)
    client = create_client(api_key)
    
    case slug
    when 'openai'
      test_openai_connection(client)
    when 'anthropic'
      test_anthropic_connection(client)
    when 'cohere'
      test_cohere_connection(client)
    else
      { success: false, error: "Unknown provider: #{slug}" }
    end
  rescue => e
    { success: false, error: e.message, error_class: e.class.name }
  end
  
  private
  
  def generate_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '')
  end
  
  def create_client(api_key)
    case slug
    when 'openai'
      require 'openai'
      OpenAI::Client.new(access_token: api_key, uri_base: api_base_url)
    when 'anthropic'
      # Would implement Anthropic client
      { api_key: api_key, base_url: api_base_url }
    when 'cohere'
      # Would implement Cohere client
      { api_key: api_key, base_url: api_base_url }
    else
      raise "Unsupported provider: #{slug}"
    end
  end
  
  def test_openai_connection(client)
    response = client.models
    if response['data']&.any?
      { success: true, message: "Successfully connected to OpenAI API", models_count: response['data'].length }
    else
      { success: false, error: "No models returned from OpenAI API" }
    end
  rescue => e
    { success: false, error: "OpenAI API error: #{e.message}", error_class: e.class.name }
  end
  
  def test_anthropic_connection(client)
    # For Anthropic, we'll try a simple completion request with minimal tokens
    # This is a placeholder - would need actual Anthropic API implementation
    {
      success: true,
      message: "Anthropic connection test (mock implementation)",
      note: "Real implementation would test with a minimal API call"
    }
  rescue => e
    { success: false, error: "Anthropic API error: #{e.message}", error_class: e.class.name }
  end
  
  def test_cohere_connection(client)
    # For Cohere, we'll try to list available models
    # This is a placeholder - would need actual Cohere API implementation
    {
      success: true,
      message: "Cohere connection test (mock implementation)",
      note: "Real implementation would test with a minimal API call"
    }
  rescue => e
    { success: false, error: "Cohere API error: #{e.message}", error_class: e.class.name }
  end
end