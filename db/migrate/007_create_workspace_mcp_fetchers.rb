# frozen_string_literal: true

class CreateWorkspaceMcpFetchers < ActiveRecord::Migration[7.0]
  def change
    create_table :workspace_mcp_fetchers do |t|
      t.references :workspace, null: false, foreign_key: true, index: true
      t.references :mcp_fetcher, null: false, foreign_key: true, index: true
      t.boolean :enabled, default: true, null: false
      t.json :workspace_configuration, default: {}
      t.timestamps

      t.index [:workspace_id, :mcp_fetcher_id], unique: true, name: 'index_workspace_mcp_fetchers_uniqueness'
      t.index :enabled
    end
  end
end