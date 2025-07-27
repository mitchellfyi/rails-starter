# frozen_string_literal: true

class CreateWorkspaceFeatureFlags < ActiveRecord::Migration[7.0]
  def change
    create_table :workspace_feature_flags do |t|
      t.references :workspace, null: false, foreign_key: true, index: true
      t.references :feature_flag, null: false, foreign_key: true, index: true
      t.boolean :enabled, default: false, null: false
      t.timestamps

      t.index [:workspace_id, :feature_flag_id], unique: true, name: 'index_workspace_feature_flags_uniqueness'
    end
  end
end