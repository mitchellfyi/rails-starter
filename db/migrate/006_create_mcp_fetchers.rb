# frozen_string_literal: true

class CreateMcpFetchers < ActiveRecord::Migration[7.0]
  def change
    create_table :mcp_fetchers do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description
      t.json :parameters, default: {}
      t.text :sample_output
      t.boolean :enabled, default: true, null: false
      t.string :provider_type, null: false
      t.json :configuration, default: {}
      t.timestamps

      t.index :enabled
      t.index :provider_type
    end
  end
end