# frozen_string_literal: true

# Model for workspace-level AI configuration including RAG and instructions
class WorkspaceAiConfig < ApplicationRecord
  belongs_to :workspace
  belongs_to :updated_by, class_name: 'User', foreign_key: 'updated_by_id'

  validates :instructions, length: { maximum: 10000 }
  validates :rag_enabled, inclusion: { in: [true, false] }
  validates :embedding_model, presence: true
  validates :chat_model, presence: true
  validates :temperature, numericality: { 
    greater_than_or_equal_to: 0.0, 
    less_than_or_equal_to: 2.0 
  }
  validates :max_tokens, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 32000 
  }

  # Default configuration values
  DEFAULTS = {
    embedding_model: 'text-embedding-ada-002',
    chat_model: 'gpt-4',
    temperature: 0.7,
    max_tokens: 4096,
    rag_enabled: true,
    auto_embed_new_content: true,
    semantic_search_threshold: 0.7,
    max_context_chunks: 10
  }.freeze

  # Available models
  EMBEDDING_MODELS = %w[
    text-embedding-ada-002
    text-embedding-3-small
    text-embedding-3-large
  ].freeze

  CHAT_MODELS = %w[
    gpt-3.5-turbo
    gpt-4
    gpt-4-turbo
    gpt-4o
    claude-3-haiku
    claude-3-sonnet
    claude-3-opus
  ].freeze

  # Initialize default configuration
  after_initialize :set_defaults, if: :new_record?

  # Serialize configuration as JSON
  def rag_config
    @rag_config ||= (super || {}).with_indifferent_access
  end

  def rag_config=(value)
    super(value.is_a?(Hash) ? value : {})
    @rag_config = nil
  end

  def model_config
    @model_config ||= (super || {}).with_indifferent_access
  end

  def model_config=(value)
    super(value.is_a?(Hash) ? value : {})
    @model_config = nil
  end

  def tools_config
    @tools_config ||= (super || {}).with_indifferent_access
  end

  def tools_config=(value)
    super(value.is_a?(Hash) ? value : {})
    @tools_config = nil
  end

  # Get effective configuration by merging defaults with overrides
  def effective_config
    DEFAULTS.merge({
      embedding_model: embedding_model,
      chat_model: chat_model,
      temperature: temperature,
      max_tokens: max_tokens,
      rag_enabled: rag_enabled,
      instructions: instructions,
      rag_config: rag_config,
      model_config: model_config,
      tools_config: tools_config
    })
  end

  # Get RAG configuration with defaults
  def effective_rag_config
    {
      enabled: rag_enabled,
      semantic_search_threshold: rag_config['semantic_search_threshold'] || DEFAULTS[:semantic_search_threshold],
      max_context_chunks: rag_config['max_context_chunks'] || DEFAULTS[:max_context_chunks],
      auto_embed_new_content: rag_config['auto_embed_new_content'] || DEFAULTS[:auto_embed_new_content],
      include_metadata: rag_config['include_metadata'] || false,
      chunk_overlap: rag_config['chunk_overlap'] || 200,
      rerank_results: rag_config['rerank_results'] || false
    }
  end

  # Get model configuration with defaults
  def effective_model_config
    {
      temperature: temperature,
      max_tokens: max_tokens,
      top_p: model_config['top_p'] || 1.0,
      frequency_penalty: model_config['frequency_penalty'] || 0.0,
      presence_penalty: model_config['presence_penalty'] || 0.0,
      stop_sequences: model_config['stop_sequences'] || [],
      response_format: model_config['response_format'] || 'text'
    }
  end

  # Get tools configuration
  def effective_tools_config
    {
      enabled_tools: tools_config['enabled_tools'] || [],
      tool_choice: tools_config['tool_choice'] || 'auto',
      parallel_tool_calls: tools_config['parallel_tool_calls'] || true,
      custom_functions: tools_config['custom_functions'] || {}
    }
  end

  # Build context for AI requests using RAG
  def build_rag_context(query, user: nil)
    return { context: '', sources: [] } unless rag_enabled

    # Get workspace embedding sources
    embedding_sources = workspace.workspace_embedding_sources.active

    all_chunks = []
    sources = []

    embedding_sources.each do |source|
      begin
        chunks = source.get_embeddings(
          query: query,
          limit: effective_rag_config[:max_context_chunks] / embedding_sources.count,
          threshold: effective_rag_config[:semantic_search_threshold]
        )
        
        all_chunks.concat(chunks)
        sources << {
          source_id: source.id,
          source_name: source.name,
          source_type: source.source_type,
          chunk_count: chunks.size
        }
      rescue => error
        Rails.logger.error "Error retrieving embeddings from source #{source.id}: #{error.message}"
      end
    end

    # Sort by similarity and take top chunks
    top_chunks = all_chunks
      .sort_by { |chunk| -chunk[:similarity_score] }
      .first(effective_rag_config[:max_context_chunks])

    # Build context string
    context_parts = top_chunks.map.with_index do |chunk, index|
      content = chunk[:content]
      metadata_str = ""
      
      if effective_rag_config[:include_metadata] && chunk[:metadata].present?
        metadata_str = " (#{chunk[:metadata].to_json})"
      end
      
      "[#{index + 1}] #{content}#{metadata_str}"
    end

    {
      context: context_parts.join("\n\n"),
      sources: sources,
      chunks_used: top_chunks.size,
      total_chunks_found: all_chunks.size
    }
  end

  # Format system prompt with instructions and context
  def format_system_prompt(context: nil)
    prompt_parts = []
    
    # Add workspace instructions
    if instructions.present?
      prompt_parts << "WORKSPACE INSTRUCTIONS:"
      prompt_parts << instructions
      prompt_parts << ""
    end

    # Add RAG context if provided
    if context.present? && rag_enabled
      prompt_parts << "RELEVANT CONTEXT:"
      prompt_parts << context
      prompt_parts << ""
      prompt_parts << "Use the above context to inform your responses when relevant. If the context doesn't contain relevant information, say so clearly."
    end

    prompt_parts.join("\n")
  end

  # Validate model availability
  def validate_models
    errors.add(:embedding_model, 'is not supported') unless EMBEDDING_MODELS.include?(embedding_model)
    errors.add(:chat_model, 'is not supported') unless CHAT_MODELS.include?(chat_model)
  end

  # Get configuration summary for display
  def summary
    {
      models: {
        chat: chat_model,
        embedding: embedding_model
      },
      settings: {
        temperature: temperature,
        max_tokens: max_tokens,
        rag_enabled: rag_enabled
      },
      sources: workspace.workspace_embedding_sources.active.count,
      last_updated: updated_at,
      updated_by: updated_by&.name
    }
  end

  private

  def set_defaults
    DEFAULTS.each do |key, value|
      send("#{key}=", value) if send(key).nil?
    end
  end
end