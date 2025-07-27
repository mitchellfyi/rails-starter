class CreateAiProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_providers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :api_base_url, null: false
      t.text :supported_models, default: '[]'
      t.text :default_config, default: '{}'
      t.integer :priority, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :ai_providers, :slug, unique: true
    add_index :ai_providers, :active
    add_index :ai_providers, :priority
  end
end