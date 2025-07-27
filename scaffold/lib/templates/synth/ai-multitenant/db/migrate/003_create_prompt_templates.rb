class CreatePromptTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_templates do |t|
      t.references :workspace, null: true, foreign_key: true
      t.references :created_by, null: true, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.text :prompt_body, null: false
      t.string :output_format, default: 'text'
      t.text :tags, default: '[]'
      t.boolean :active, default: true
      t.boolean :is_public, default: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :prompt_templates, :slug, unique: true
    add_index :prompt_templates, [:workspace_id, :active]
    add_index :prompt_templates, :is_public
    add_index :prompt_templates, :created_by_id
  end
end