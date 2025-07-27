# frozen_string_literal: true

# Model for linking embeddings to specific context fetchers or semantic memory
class WorkspaceEmbeddingSource < ApplicationRecord
  belongs_to :workspace
  belongs_to :ai_dataset, optional: true
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'

  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :source_type, presence: true, inclusion: { 
    in: %w[dataset context_fetcher semantic_memory external_api manual] 
  }
  validates :status, presence: true, inclusion: { 
    in: %w[active inactive processing error] 
  }

  scope :active, -> { where(status: 'active') }
  scope :by_type, ->(type) { where(source_type: type) if type.present? }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) if workspace.present? }

  # Configuration for different source types
  def configuration
    @configuration ||= (config || {}).with_indifferent_access
  end

  def configuration=(value)
    self.config = value.is_a?(Hash) ? value : {}
  end

  # Check if source is ready to use
  def ready?
    status == 'active' && has_valid_configuration?
  end

  # Get embeddings from this source
  def get_embeddings(query: nil, limit: 10, threshold: 0.7)
    case source_type
    when 'dataset'
      get_dataset_embeddings(query: query, limit: limit, threshold: threshold)
    when 'context_fetcher'
      get_context_fetcher_embeddings(query: query, limit: limit, threshold: threshold)
    when 'semantic_memory'
      get_semantic_memory_embeddings(query: query, limit: limit, threshold: threshold)
    when 'external_api'
      get_external_api_embeddings(query: query, limit: limit, threshold: threshold)
    when 'manual'
      get_manual_embeddings(query: query, limit: limit, threshold: threshold)
    else
      []
    end
  end

  # Test the embedding source
  def test_connection
    begin
      result = get_embeddings(query: "test query", limit: 1)
      update!(status: 'active', last_tested_at: Time.current)
      { success: true, message: "Connection successful", result_count: result.size }
    rescue => error
      update!(status: 'error', last_tested_at: Time.current)
      { success: false, message: error.message }
    end
  end

  # Refresh/reindex embeddings
  def refresh_embeddings!
    return unless ready?

    case source_type
    when 'dataset'
      refresh_dataset_embeddings!
    when 'context_fetcher'
      refresh_context_fetcher_embeddings!
    when 'semantic_memory'
      refresh_semantic_memory_embeddings!
    when 'external_api'
      refresh_external_api_embeddings!
    when 'manual'
      # Manual embeddings don't need refreshing
      true
    else
      false
    end
  end

  # Get source statistics
  def statistics
    embedding_count = VectorEmbedding.for_workspace(workspace)
                                   .where(namespace: namespace)
                                   .count

    {
      embedding_count: embedding_count,
      status: status,
      source_type: source_type,
      last_tested: last_tested_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Get namespace for this source
  def namespace
    case source_type
    when 'dataset'
      ai_dataset ? "dataset_#{ai_dataset.id}" : "source_#{id}"
    else
      "source_#{id}"
    end
  end

  private

  def has_valid_configuration?
    case source_type
    when 'dataset'
      ai_dataset&.ready?
    when 'context_fetcher'
      configuration['fetcher_name'].present? && configuration['endpoint'].present?
    when 'semantic_memory'
      configuration['memory_type'].present?
    when 'external_api'
      configuration['api_endpoint'].present? && configuration['api_key'].present?
    when 'manual'
      true
    else
      false
    end
  end

  def get_dataset_embeddings(query:, limit:, threshold:)
    return [] unless ai_dataset&.ready?

    if query.present?
      query_vector = generate_query_embedding(query)
      VectorEmbedding.semantic_search(
        query_vector: query_vector,
        threshold: threshold,
        limit: limit,
        workspace: workspace,
        namespace: namespace
      )
    else
      VectorEmbedding.for_workspace(workspace)
                    .in_namespace(namespace)
                    .limit(limit)
                    .map do |embedding|
        {
          id: embedding.id,
          content: embedding.content,
          similarity_score: 1.0,
          metadata: embedding.metadata,
          embedding_id: embedding.id,
          namespace: embedding.namespace,
          content_type: embedding.content_type,
          created_at: embedding.created_at
        }
      end
    end
  end

  def get_context_fetcher_embeddings(query:, limit:, threshold:)
    # This would integrate with MCP (Multi-Context Provider) system
    # For now, return empty array
    []
  end

  def get_semantic_memory_embeddings(query:, limit:, threshold:)
    # This would integrate with a semantic memory system
    # For now, return empty array
    []
  end

  def get_external_api_embeddings(query:, limit:, threshold:)
    # This would call external APIs for embeddings
    # For now, return empty array
    []
  end

  def get_manual_embeddings(query:, limit:, threshold:)
    # Get manually created embeddings for this source
    if query.present?
      query_vector = generate_query_embedding(query)
      VectorEmbedding.semantic_search(
        query_vector: query_vector,
        threshold: threshold,
        limit: limit,
        workspace: workspace,
        namespace: namespace
      )
    else
      VectorEmbedding.for_workspace(workspace)
                    .in_namespace(namespace)
                    .limit(limit)
                    .map do |embedding|
        {
          id: embedding.id,
          content: embedding.content,
          similarity_score: 1.0,
          metadata: embedding.metadata,
          embedding_id: embedding.id,
          namespace: embedding.namespace,
          content_type: embedding.content_type,
          created_at: embedding.created_at
        }
      end
    end
  end

  def refresh_dataset_embeddings!
    return false unless ai_dataset

    ai_dataset.create_embeddings!
  end

  def refresh_context_fetcher_embeddings!
    # Implementation for refreshing context fetcher embeddings
    true
  end

  def refresh_semantic_memory_embeddings!
    # Implementation for refreshing semantic memory embeddings
    true
  end

  def refresh_external_api_embeddings!
    # Implementation for refreshing external API embeddings
    true
  end

  def generate_query_embedding(query)
    # Placeholder for actual embedding generation
    # In a real implementation, this would call OpenAI embeddings API
    Array.new(1536) { rand(-1.0..1.0) }
  end
end