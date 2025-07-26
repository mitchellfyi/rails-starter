# frozen_string_literal: true

class CreatePromptTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.text :prompt_body, null: false
      t.string :output_format, null: false, default: 'text'
      t.string :tags, array: true, default: []
      t.references :workspace, foreign_key: true, null: true
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.boolean :active, default: true
      t.boolean :published, default: false
      t.string :version, default: '1.0.0'
      
      t.timestamps
    end

    add_index :prompt_templates, [:workspace_id, :name], unique: true
    add_index :prompt_templates, [:workspace_id, :slug], unique: true
    add_index :prompt_templates, :tags, using: 'gin'
    add_index :prompt_templates, :output_format
    add_index :prompt_templates, :active
    add_index :prompt_templates, :published
    add_index :prompt_templates, :version
  end
end