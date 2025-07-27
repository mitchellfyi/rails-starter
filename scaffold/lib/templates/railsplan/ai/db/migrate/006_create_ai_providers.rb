# frozen_string_literal: true

class CreateAiProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_providers do |t|
      t.string :name, null: false           # e.g., "OpenAI", "Anthropic", "Cohere"
      t.string :slug, null: false           # e.g., "openai", "anthropic", "cohere"
      t.text :description
      t.string :api_base_url                # e.g., "https://api.openai.com"
      t.json :supported_models, default: [] # e.g., ["gpt-4", "gpt-3.5-turbo"]
      t.json :default_config, default: {}   # Default settings for this provider
      t.boolean :active, default: true
      t.integer :priority, default: 0       # For ordering in UIs
      
      t.timestamps
    end

    add_index :ai_providers, :slug, unique: true
    add_index :ai_providers, :active
    add_index :ai_providers, :priority
  end
end