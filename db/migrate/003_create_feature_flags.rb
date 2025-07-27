# frozen_string_literal: true

class CreateFeatureFlags < ActiveRecord::Migration[7.0]
  def change
    create_table :feature_flags do |t|
      t.string :name, null: false, index: { unique: true }
      t.text :description, null: false
      t.boolean :enabled, default: false, null: false, index: true
      t.timestamps
    end
  end
end