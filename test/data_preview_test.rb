# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'json'
require 'ostruct'

# Load only the specific components we need for testing
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'railsplan/data_preview'

# Mock ActiveRecord for testing
module MockActiveRecord
  class Base
    def self.descendants
      []
    end
    
    def self.connection
      MockConnection.new
    end
  end
  
  class MockConnection
    def quote_table_name(name)
      "`#{name}`"
    end
    
    def select_all(sql)
      MockResult.new
    end
    
    def execute(sql)
      []
    end
  end
  
  class MockResult
    def to_a
      []
    end
    
    def length
      0
    end
  end
end

class DataPreviewTest < Minitest::Test
  def setup
    # Mock ActiveRecord if not available
    unless defined?(ActiveRecord)
      Object.const_set(:ActiveRecord, MockActiveRecord)
    end
  end
  
  def test_validate_limit
    preview = RailsPlan::DataPreview.new
    
    # Test normal limit
    assert_equal 10, preview.send(:validate_limit!, 10)
    
    # Test limit too high
    assert_equal 100, preview.send(:validate_limit!, 500)
    
    # Test limit too low
    assert_equal 1, preview.send(:validate_limit!, 0)
    assert_equal 1, preview.send(:validate_limit!, -5)
  end
  
  def test_validate_table_name
    preview = RailsPlan::DataPreview.new
    
    # Valid table names should not raise errors
    begin
      preview.send(:validate_table_name!, "users")
      preview.send(:validate_table_name!, "user_profiles")
      preview.send(:validate_table_name!, "_temp_table")
    rescue => e
      assert false, "Valid table names should not raise errors: #{e.message}"
    end
    
    # Invalid table names should raise errors
    assert_raises(RailsPlan::DataPreview::QueryError) do
      preview.send(:validate_table_name!, "users; DROP TABLE users;")
    end
    
    assert_raises(RailsPlan::DataPreview::QueryError) do
      preview.send(:validate_table_name!, "123_invalid")
    end
  end
  
  def test_validate_sql_safety
    preview = RailsPlan::DataPreview.new
    
    # Safe queries should not raise errors
    begin
      preview.send(:validate_sql_safety!, "SELECT * FROM users")
      preview.send(:validate_sql_safety!, "SELECT id, name FROM users WHERE active = true LIMIT 10")
    rescue => e
      assert false, "Safe queries should not raise errors: #{e.message}"
    end
    
    # Dangerous queries
    assert_raises(RailsPlan::DataPreview::UnsafeQueryError) do
      preview.send(:validate_sql_safety!, "DROP TABLE users")
    end
    
    assert_raises(RailsPlan::DataPreview::UnsafeQueryError) do
      preview.send(:validate_sql_safety!, "INSERT INTO users (name) VALUES ('test')")
    end
    
    assert_raises(RailsPlan::DataPreview::UnsafeQueryError) do
      preview.send(:validate_sql_safety!, "UPDATE users SET name = 'hacked'")
    end
    
    # Multi-statement attempts
    assert_raises(RailsPlan::DataPreview::UnsafeQueryError) do
      preview.send(:validate_sql_safety!, "SELECT * FROM users; DROP TABLE users;")
    end
  end
  
  def test_serialize_results
    preview = RailsPlan::DataPreview.new
    
    # Test with hash-like objects
    mock_record = OpenStruct.new(id: 1, name: "Test")
    def mock_record.attributes
      { "id" => 1, "name" => "Test" }
    end
    
    results = [mock_record]
    serialized = preview.send(:serialize_results, results)
    
    assert_equal [{ "id" => 1, "name" => "Test" }], serialized
  end
end