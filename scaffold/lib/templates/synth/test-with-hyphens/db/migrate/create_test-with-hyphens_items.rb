# frozen_string_literal: true

class CreateTestWithHyphensItems < ActiveRecord::Migration[7.0]
  def change
    create_table :test-with-hyphens_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :test-with-hyphens_items, [:user_id, :active]
    add_index :test-with-hyphens_items, :name
    add_index :test-with-hyphens_items, :created_at
  end
end
