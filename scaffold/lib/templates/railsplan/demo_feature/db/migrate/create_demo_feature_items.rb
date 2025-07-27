# frozen_string_literal: true

class CreateDemoFeatureItems < ActiveRecord::Migration[7.0]
  def change
    create_table :demo_feature_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :demo_feature_items, [:user_id, :active]
    add_index :demo_feature_items, :name
    add_index :demo_feature_items, :created_at
  end
end
