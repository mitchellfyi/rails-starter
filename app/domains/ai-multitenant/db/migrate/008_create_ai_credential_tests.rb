class CreateAiCredentialTests < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_credential_tests do |t|
      t.references :ai_credential, null: false, foreign_key: true
      t.boolean :successful, default: false
      t.text :error_message
      t.decimal :response_time, precision: 8, scale: 3
      t.datetime :tested_at, null: false

      t.timestamps
    end

    add_index :ai_credential_tests, [:ai_credential_id, :tested_at]
    add_index :ai_credential_tests, :successful
  end
end