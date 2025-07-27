# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_07_27_163819) do
  create_table "audit_logs", force: :cascade do |t|
    t.integer "user_id"
    t.string "action", null: false
    t.string "resource_type"
    t.bigint "resource_id"
    t.text "description", null: false
    t.json "metadata", default: {}
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_audit_logs_on_action_and_created_at"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["resource_type"], name: "index_audit_logs_on_resource_type"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "feature_flags", force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_feature_flags_on_enabled"
    t.index ["name"], name: "index_feature_flags_on_name", unique: true
  end

  create_table "mcp_fetchers", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.json "parameters", default: {}
    t.text "sample_output"
    t.boolean "enabled", default: true, null: false
    t.string "provider_type", null: false
    t.json "configuration", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_mcp_fetchers_on_enabled"
    t.index ["name"], name: "index_mcp_fetchers_on_name", unique: true
    t.index ["provider_type"], name: "index_mcp_fetchers_on_provider_type"
  end

  create_table "system_prompts", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.text "prompt_text", null: false
    t.string "status", default: "draft", null: false
    t.integer "workspace_id"
    t.integer "created_by_id"
    t.string "version", default: "1.0.0"
    t.text "associated_roles"
    t.text "associated_functions"
    t.text "associated_agents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_system_prompts_on_created_by_id"
    t.index ["status"], name: "index_system_prompts_on_status"
    t.index ["version"], name: "index_system_prompts_on_version"
    t.index ["workspace_id", "name"], name: "index_system_prompts_on_workspace_id_and_name", unique: true
    t.index ["workspace_id", "slug"], name: "index_system_prompts_on_workspace_id_and_slug", unique: true
    t.index ["workspace_id"], name: "index_system_prompts_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest"
    t.string "first_name"
    t.string "last_name"
    t.datetime "confirmed_at"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.text "encrypted_two_factor_secret"
    t.text "encrypted_two_factor_secret_iv"
    t.text "backup_codes"
    t.text "encrypted_first_name"
    t.text "encrypted_first_name_iv"
    t.text "encrypted_last_name"
    t.text "encrypted_last_name_iv"
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["encrypted_first_name_iv"], name: "index_users_on_encrypted_first_name_iv"
    t.index ["encrypted_last_name_iv"], name: "index_users_on_encrypted_last_name_iv"
    t.index ["encrypted_two_factor_secret_iv"], name: "index_users_on_encrypted_two_factor_secret_iv"
  end

  create_table "workspace_feature_flags", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "feature_flag_id", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_flag_id"], name: "index_workspace_feature_flags_on_feature_flag_id"
    t.index ["workspace_id", "feature_flag_id"], name: "index_workspace_feature_flags_uniqueness", unique: true
    t.index ["workspace_id"], name: "index_workspace_feature_flags_on_workspace_id"
  end

  create_table "workspace_mcp_fetchers", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "mcp_fetcher_id", null: false
    t.boolean "enabled", default: true, null: false
    t.json "workspace_configuration", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_workspace_mcp_fetchers_on_enabled"
    t.index ["mcp_fetcher_id"], name: "index_workspace_mcp_fetchers_on_mcp_fetcher_id"
    t.index ["workspace_id", "mcp_fetcher_id"], name: "index_workspace_mcp_fetchers_uniqueness", unique: true
    t.index ["workspace_id"], name: "index_workspace_mcp_fetchers_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "monthly_ai_credit", precision: 10, scale: 6, default: "10.0"
    t.decimal "current_month_usage", precision: 10, scale: 6, default: "0.0"
    t.date "usage_reset_date"
    t.boolean "overage_billing_enabled", default: false
    t.string "stripe_meter_id"
    t.index ["active"], name: "index_workspaces_on_active"
    t.index ["name"], name: "index_workspaces_on_name"
    t.index ["overage_billing_enabled"], name: "index_workspaces_on_overage_billing_enabled"
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
    t.index ["usage_reset_date"], name: "index_workspaces_on_usage_reset_date"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "system_prompts", "users", column: "created_by_id"
  add_foreign_key "system_prompts", "workspaces"
  add_foreign_key "workspace_feature_flags", "feature_flags"
  add_foreign_key "workspace_feature_flags", "workspaces"
  add_foreign_key "workspace_mcp_fetchers", "mcp_fetchers"
  add_foreign_key "workspace_mcp_fetchers", "workspaces"
end
