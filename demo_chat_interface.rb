#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for RailsPlan Schema-Aware Chat Interface
puts "🤖 RailsPlan Schema-Aware Chat Interface Demo"
puts "=" * 50

# Create a sample schema for demonstration
sample_schema = {
  "users" => {
    "columns" => {
      "id" => { "type" => "bigint" },
      "email" => { "type" => "string", "null" => false },
      "name" => { "type" => "string", "limit" => 100 },
      "created_at" => { "type" => "datetime" },
      "updated_at" => { "type" => "datetime" }
    },
    "indexes" => [
      { "columns" => ["email"], "unique" => true, "name" => "index_users_on_email" }
    ]
  },
  "posts" => {
    "columns" => {
      "id" => { "type" => "bigint" },
      "user_id" => { "type" => "bigint", "null" => false },
      "title" => { "type" => "string" },
      "content" => { "type" => "text" },
      "status" => { "type" => "string", "default" => "draft" },
      "created_at" => { "type" => "datetime" },
      "updated_at" => { "type" => "datetime" }
    },
    "indexes" => [
      { "columns" => ["user_id"], "name" => "index_posts_on_user_id" },
      { "columns" => ["status", "created_at"], "name" => "index_posts_on_status_and_created_at" }
    ]
  },
  "comments" => {
    "columns" => {
      "id" => { "type" => "bigint" },
      "post_id" => { "type" => "bigint", "null" => false },
      "author_email" => { "type" => "string" },
      "content" => { "type" => "text" },
      "approved" => { "type" => "boolean", "default" => false },
      "created_at" => { "type" => "datetime" }
    },
    "indexes" => [
      { "columns" => ["post_id"], "name" => "index_comments_on_post_id" }
    ]
  }
}

sample_models = [
  {
    "class_name" => "User",
    "associations" => [
      { "type" => "has_many", "name" => "posts" },
      { "type" => "has_many", "name" => "comments", "through" => "posts" }
    ],
    "validations" => [
      { "field" => "email", "rules" => "presence: true, uniqueness: true" },
      { "field" => "name", "rules" => "presence: true, length: { maximum: 100 }" }
    ]
  },
  {
    "class_name" => "Post", 
    "associations" => [
      { "type" => "belongs_to", "name" => "user" },
      { "type" => "has_many", "name" => "comments" }
    ],
    "validations" => [
      { "field" => "title", "rules" => "presence: true" },
      { "field" => "user", "rules" => "presence: true" }
    ]
  },
  {
    "class_name" => "Comment",
    "associations" => [
      { "type" => "belongs_to", "name" => "post" }
    ],
    "validations" => [
      { "field" => "content", "rules" => "presence: true" },
      { "field" => "post", "rules" => "presence: true" }
    ]
  }
]

puts "\n📊 Sample Application Schema:"
puts "-" * 30

sample_schema.each do |table_name, table_info|
  puts "\n🗄️  Table: #{table_name}"
  puts "   Columns:"
  table_info["columns"].each do |col_name, col_info|
    constraints = []
    constraints << "NOT NULL" if col_info["null"] == false
    constraints << "UNIQUE" if col_info["unique"]
    constraints << "DEFAULT: #{col_info["default"]}" if col_info["default"]
    constraints << "LIMIT: #{col_info["limit"]}" if col_info["limit"]
    
    constraint_str = constraints.any? ? " (#{constraints.join(", ")})" : ""
    puts "     - #{col_name}: #{col_info["type"]}#{constraint_str}"
  end
  
  if table_info["indexes"]&.any?
    puts "   Indexes:"
    table_info["indexes"].each do |index|
      unique_str = index["unique"] ? " UNIQUE" : ""
      puts "     - #{index["name"]}#{unique_str}: [#{index["columns"].join(", ")}]"
    end
  end
end

puts "\n🏗️  Sample Models:"
puts "-" * 20

sample_models.each do |model|
  puts "\n📝 Model: #{model["class_name"]}"
  
  if model["associations"]&.any?
    puts "   Associations:"
    model["associations"].each do |assoc|
      through_str = assoc["through"] ? " (through: #{assoc["through"]})" : ""
      puts "     - #{assoc["type"]} :#{assoc["name"]}#{through_str}"
    end
  end
  
  if model["validations"]&.any?
    puts "   Validations:"
    model["validations"].each do |validation|
      puts "     - #{validation["field"]}: #{validation["rules"]}"
    end
  end
end

puts "\n💬 Sample Chat Interactions:"
puts "-" * 30

sample_questions = [
  {
    question: "What models do I have in my application?",
    answer: "You have 3 models: User, Post, and Comment. Users can have many posts, posts belong to users and can have many comments, and comments belong to posts."
  },
  {
    question: "Show me the schema for the users table",
    answer: "The users table has: id (bigint), email (string, NOT NULL, UNIQUE), name (string, max 100 chars), created_at and updated_at (datetime). It has a unique index on email."
  },
  {
    question: "How are User and Post models related?",
    answer: "User has_many :posts, and Post belongs_to :user. The posts table has a user_id foreign key with an index."
  },
  {
    question: "What validations does the User model have?",
    answer: "User validates: email (presence: true, uniqueness: true) and name (presence: true, length: { maximum: 100 })."
  },
  {
    question: "Show me sample data from posts table",
    answer: "💾 Data Mode: Here are 5 sample posts:\n| id | user_id | title | status | created_at |\n|1|1|Hello World|published|2024-01-01|\n|2|1|Draft Post|draft|2024-01-02|\n|3|2|Welcome|published|2024-01-03|"
  }
]

sample_questions.each_with_index do |qa, i|
  puts "\n#{i + 1}. 👤 User: #{qa[:question]}"
  puts "   🤖 AI: #{qa[:answer]}"
end

puts "\n🔒 Security Features Demonstrated:"
puts "-" * 35

# Test SQL safety
require_relative 'lib/railsplan/data_preview'

preview = RailsPlan::DataPreview.new

safe_queries = [
  "SELECT * FROM users LIMIT 10",
  "SELECT COUNT(*) FROM posts WHERE status = 'published'",
  "SELECT users.name, COUNT(posts.id) FROM users LEFT JOIN posts ON users.id = posts.user_id GROUP BY users.id"
]

unsafe_queries = [
  "DROP TABLE users",
  "DELETE FROM posts",
  "UPDATE users SET email = 'hacked@evil.com'",
  "INSERT INTO users (email) VALUES ('spam@test.com')"
]

puts "\n✅ Safe queries (allowed):"
safe_queries.each do |query|
  begin
    preview.send(:validate_sql_safety!, query)
    puts "   ✓ #{query}"
  rescue => e
    puts "   ✗ #{query} - #{e.message}"
  end
end

puts "\n❌ Unsafe queries (blocked):"
unsafe_queries.each do |query|
  begin
    preview.send(:validate_sql_safety!, query)
    puts "   ✗ #{query} - Should have been blocked!"
  rescue RailsPlan::DataPreview::UnsafeQueryError => e
    puts "   ✓ #{query} - Correctly blocked"
  end
end

puts "\n🎯 Key Features Summary:"
puts "-" * 25
puts "✅ Schema-aware AI responses"
puts "✅ Safe database query execution"
puts "✅ SQL injection prevention"
puts "✅ Interactive web interface with Hotwire"
puts "✅ Configurable query limits and permissions"
puts "✅ Audit logging for data access"
puts "✅ Context-aware suggestions"
puts "✅ Real-time streaming responses"

puts "\n🚀 To use in a RailsPlan app:"
puts "-" * 30
puts "1. Generate a new app: railsplan new myapp"
puts "2. Start the server: cd myapp && bin/rails server"
puts "3. Visit: http://localhost:3000/railsplan/chat"
puts "4. Ask questions about your app and data!"

puts "\n" + "=" * 50
puts "Demo completed! The schema-aware chat interface is ready. 🎉"