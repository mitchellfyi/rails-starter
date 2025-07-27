# frozen_string_literal: true

# Add helper method for checking gem existence
def gem_exists?(gem_name)
  File.read('Gemfile').include?(gem_name)
end

say "🔧 Setting up Rails application..."

# Install Hotwire and Tailwind
rails_command 'turbo:install'
rails_command 'stimulus:install'
rails_command 'tailwindcss:install'

# Configure database for PostgreSQL with pgvector
say "📊 Configuring PostgreSQL with pgvector..."

initializer 'postgresql.rb', <<~RUBY
  # PostgreSQL configuration
  # Enable pgvector extension for vector embeddings
  Rails.application.configure do
    config.after_initialize do
      if Rails.env.development? || Rails.env.test?
        begin
          ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector;')
        rescue ActiveRecord::StatementInvalid => e
          Rails.logger.warn "Could not create vector extension: #{e.message}"
        end
      end
    end
  end
RUBY

# Set up RSpec if included
generate 'rspec:install' if gem_exists?('rspec-rails')

if gem_exists?('rspec-rails')
  inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
    <<~RUBY

  # Add additional requires below this line. Rails is not loaded until this point!

  # Require all files in spec/domains
  Dir[Rails.root.join('spec/domains/**/*.rb')].each { |f| require f }

  # Require shared contexts
  require 'support/authentication_helpers'
  require 'support/llm_stubs'
  require 'support/billing_stubs'
    RUBY
  end
end

# Configure Shoulda Matchers if present
if gem_exists?('shoulda-matchers')
  create_file 'spec/support/shoulda_matchers.rb', <<~RUBY
    # frozen_string_literal: true

    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end
  RUBY
end
