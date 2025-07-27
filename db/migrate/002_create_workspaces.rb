# frozen_string_literal: true

class CreateWorkspaces < ActiveRecord::Migration[7.0]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.text :description
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index :name
      t.index :active
    end
  end
end