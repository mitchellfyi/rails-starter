class CreateAiUsageSummaries < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_usage_summaries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :ai_credential, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :requests_count, default: 0
      t.integer :tokens_used, default: 0
      t.decimal :estimated_cost, precision: 10, scale: 6, default: 0.0
      t.integer :successful_requests, default: 0
      t.integer :failed_requests, default: 0
      t.decimal :avg_response_time, precision: 8, scale: 3, default: 0.0
      t.integer :unique_users, default: 0

      t.timestamps
    end

    add_index :ai_usage_summaries, [:workspace_id, :date]
    add_index :ai_usage_summaries, [:workspace_id, :ai_credential_id, :date], 
              unique: true, name: 'index_ai_usage_summaries_unique'
    add_index :ai_usage_summaries, :date
  end
end