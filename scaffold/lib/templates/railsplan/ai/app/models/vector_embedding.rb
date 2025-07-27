# frozen_string_literal: true

# Model for storing vector embeddings using pgvector for semantic search
class VectorEmbedding < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :workspace, optional: true

  validates :content, presence: true
  validates :embedding, presence: true
  validates :content_type, presence: true

  # pgvector scope for similarity search
  scope :similar_to, ->(vector, limit: 10) {
    order(embedding: { nearest: { vector: vector, distance: :cosine } })
      .limit(limit)
  }

  # Scope by namespace
  scope :in_namespace, ->(namespace) { where(namespace: namespace) if namespace.present? }

  # Scope by content type
  scope :of_type, ->(types) { where(content_type: types) if types.present? }

  # Scope by user/workspace
  scope :for_user, ->(user) { where(user: user) if user.present? }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) if workspace.present? }

  # Search embeddings with similarity threshold
  def self.semantic_search(query_vector:, threshold: 0.7, limit: 10, **filters)
    relation = all
    
    # Apply filters
    relation = relation.in_namespace(filters[:namespace])
    relation = relation.of_type(filters[:content_types])
    relation = relation.for_user(filters[:user])
    relation = relation.for_workspace(filters[:workspace])
    
    # Exclude specific IDs
    relation = relation.where.not(id: filters[:exclude_ids]) if filters[:exclude_ids].present?
    
    # Apply metadata filters
    if filters[:metadata_filter].present?
      filters[:metadata_filter].each do |key, value|
        relation = relation.where("metadata->>'#{key}' = ?", value)
      end
    end
    
    # Perform similarity search
    results = relation.similar_to(query_vector, limit: limit * 2) # Get more to filter by threshold
    
    # Filter by similarity threshold and format results
    results.filter_map do |embedding|
      similarity = calculate_similarity(query_vector, embedding.embedding)
      if similarity >= threshold
        {
          id: embedding.id,
          content: embedding.content,
          similarity_score: similarity,
          metadata: embedding.metadata,
          embedding_id: embedding.id,
          namespace: embedding.namespace,
          content_type: embedding.content_type,
          created_at: embedding.created_at
        }
      end
    end.first(limit)
  end

  # Calculate cosine similarity between two vectors
  def self.calculate_similarity(vector1, vector2)
    return 0.0 if vector1.empty? || vector2.empty? || vector1.size != vector2.size
    
    dot_product = vector1.zip(vector2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(vector1.sum { |a| a * a })
    magnitude2 = Math.sqrt(vector2.sum { |a| a * a })
    
    return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0
    
    dot_product / (magnitude1 * magnitude2)
  end

  # Get embedding statistics
  def self.stats(user: nil, workspace: nil, namespace: nil)
    relation = all
    relation = relation.for_user(user)
    relation = relation.for_workspace(workspace)
    relation = relation.in_namespace(namespace)
    
    {
      total_embeddings: relation.count,
      namespaces: relation.distinct.pluck(:namespace).compact,
      content_types: relation.distinct.pluck(:content_type).compact,
      last_updated: relation.maximum(:updated_at)
    }
  end

  # Convert embedding array to pgvector format
  def embedding=(value)
    case value
    when Array
      super(value)
    when String
      super(JSON.parse(value))
    else
      super(value)
    end
  end

  # Ensure embedding is always an array when read
  def embedding
    value = super
    value.is_a?(String) ? JSON.parse(value) : value
  end
end