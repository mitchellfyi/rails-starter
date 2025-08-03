# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'json'

# Load only the specific components we need for testing
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'railsplan/context_manager'

class ContextManagerSchemaTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("railsplan_test")
    @context_manager = RailsPlan::ContextManager.new(@temp_dir)
  end
  
  def teardown
    FileUtils.rm_rf(@temp_dir)
  end
  
  def test_parse_schema_with_enhanced_information
    schema_content = <<~SCHEMA
      ActiveRecord::Schema.define(version: 2023_01_01_000001) do
        create_table "users", force: :cascade do |t|
          t.string "email", null: false
          t.string "name", limit: 100
          t.boolean "active", default: true
          t.timestamps null: false
          t.index ["email"], name: "index_users_on_email", unique: true
        end
        
        create_table "posts", force: :cascade do |t|
          t.references "user", null: false, foreign_key: true
          t.string "title"
          t.text "content"
          t.timestamps null: false
        end
        
        add_index "posts", ["user_id", "created_at"], name: "index_posts_on_user_id_and_created_at"
      end
    SCHEMA
    
    result = @context_manager.send(:parse_schema, schema_content)
    
    # Test users table
    assert result["users"]
    assert_equal "string", result["users"]["columns"]["email"]["type"]
    assert_equal "string", result["users"]["columns"]["name"]["type"]
    assert_equal "boolean", result["users"]["columns"]["active"]["type"]
    
    # Test that indexes are captured
    assert result["users"]["indexes"]
    user_indexes = result["users"]["indexes"]
    email_index = user_indexes.find { |idx| idx["columns"] == ["email"] }
    assert email_index
    assert email_index["unique"]
    
    # Test posts table
    assert result["posts"]
    assert_equal "references", result["posts"]["columns"]["user"]["type"]
    
    # Test standalone indexes
    assert result["posts"]["indexes"]
    post_indexes = result["posts"]["indexes"]
    compound_index = post_indexes.find { |idx| idx["columns"] == ["user_id", "created_at"] }
    assert compound_index
  end
  
  def test_parse_column_options
    context_manager = @context_manager
    
    # Test null constraint
    options = context_manager.send(:parse_column_options, "null: false")
    assert_equal false, options["null"]
    
    # Test default value
    options = context_manager.send(:parse_column_options, "default: true")
    assert_equal "true", options["default"]
    
    # Test limit
    options = context_manager.send(:parse_column_options, "limit: 100")
    assert_equal 100, options["limit"]
    
    # Test unique
    options = context_manager.send(:parse_column_options, "unique: true")
    assert options["unique"]
    
    # Test combined options
    options = context_manager.send(:parse_column_options, "null: false, limit: 255, default: 'test'")
    assert_equal false, options["null"]
    assert_equal 255, options["limit"]
    assert_equal "'test'", options["default"]
  end
  
  def test_extract_table_indexes
    content = <<~SCHEMA
      create_table "users", force: :cascade do |t|
        t.string "email"
        t.string "name"
        t.index ["email"], name: "index_users_on_email", unique: true
        t.index ["name", "email"], name: "index_users_on_name_and_email"
      end
    SCHEMA
    
    indexes = @context_manager.send(:extract_table_indexes, content, "users")
    
    assert_equal 2, indexes.length
    
    email_index = indexes.find { |idx| idx["columns"] == ["email"] }
    assert email_index
    assert email_index["unique"]
    assert_equal "index_users_on_email", email_index["name"]
    
    compound_index = indexes.find { |idx| idx["columns"] == ["name", "email"] }
    assert compound_index
    assert_nil compound_index["unique"]
  end
  
  def test_parse_index_definition
    context_manager = @context_manager
    
    # Test single column index
    index_info = context_manager.send(:parse_index_definition, '["email"], name: "index_users_on_email", unique: true')
    assert_equal ["email"], index_info["columns"]
    assert index_info["unique"]
    assert_equal "index_users_on_email", index_info["name"]
    
    # Test multiple column index
    index_info = context_manager.send(:parse_index_definition, '["name", "email"]')
    assert_equal ["name", "email"], index_info["columns"]
    
    # Test symbol format
    index_info = context_manager.send(:parse_index_definition, ':email, unique: true')
    assert_equal ["email"], index_info["columns"]
    assert index_info["unique"]
  end
  
  def test_enhanced_schema_extraction
    # Create a mock schema file
    schema_file = File.join(@temp_dir, "db", "schema.rb")
    FileUtils.mkdir_p(File.dirname(schema_file))
    
    File.write(schema_file, <<~SCHEMA)
      ActiveRecord::Schema.define(version: 2023_01_01_000001) do
        create_table "users", force: :cascade do |t|
          t.string "email", null: false
          t.string "name", limit: 100
          t.boolean "active", default: true
          t.timestamps null: false
          t.index ["email"], name: "index_users_on_email", unique: true
        end
      end
    SCHEMA
    
    result = @context_manager.extract_schema
    
    assert result["users"]
    assert result["users"]["columns"]
    assert result["users"]["indexes"]
    
    # Verify column information
    email_col = result["users"]["columns"]["email"]
    assert_equal "string", email_col["type"]
    
    # Verify index information  
    indexes = result["users"]["indexes"]
    assert indexes.any? { |idx| idx["columns"] == ["email"] && idx["unique"] }
  end
end