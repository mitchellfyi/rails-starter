# frozen_string_literal: true

class CreateVectorEmbeddings < ActiveRecord::Migration[7.1]
  def up
    # Enable pgvector extension
    enable_extension 'vector'
    
    create_table :vector_embeddings do |t|
      t.text :content, null: false
      t.vector :embedding, limit: 1536, null: false # OpenAI ada-002 dimensions
      t.string :content_type, null: false
      t.string :namespace
      t.json :metadata, default: {}
      t.references :user, null: true, foreign_key: true
      t.references :workspace, null: true, foreign_key: true
      
      t.timestamps
    end
    
    # Add indexes for efficient querying
    add_index :vector_embeddings, :content_type
    add_index :vector_embeddings, :namespace
    add_index :vector_embeddings, [:user_id, :content_type]
    add_index :vector_embeddings, [:workspace_id, :content_type]
    add_index :vector_embeddings, :created_at
    
    # Add pgvector index for similarity search
    add_index :vector_embeddings, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end

  def down
    drop_table :vector_embeddings
    disable_extension 'vector'
  end
end