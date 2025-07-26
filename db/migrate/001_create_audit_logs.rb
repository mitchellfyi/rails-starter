# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: true, index: true
      t.string :action, null: false, index: true
      t.string :resource_type, null: true, index: true
      t.bigint :resource_id, null: true
      t.text :description, null: false
      t.json :metadata, default: {}
      t.string :ip_address
      t.text :user_agent
      t.timestamps

      t.index [:resource_type, :resource_id]
      t.index [:action, :created_at]
      t.index :created_at
    end
  end
end