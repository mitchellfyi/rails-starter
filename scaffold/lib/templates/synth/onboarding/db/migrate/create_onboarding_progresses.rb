# frozen_string_literal: true

class CreateOnboardingProgresses < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :current_step, null: false, default: 'welcome'
      t.json :completed_steps, null: false, default: []
      t.boolean :skipped, default: false, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :onboarding_progresses, :user_id, unique: true
    add_index :onboarding_progresses, :current_step
    add_index :onboarding_progresses, :completed_at
    add_index :onboarding_progresses, :skipped
  end
end