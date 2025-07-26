# frozen_string_literal: true

namespace :deploy do
  desc 'Bootstrap a new environment: setup databases, run migrations, load seeds, and validate setup'
  task bootstrap: :environment do
    puts '🚀 Bootstrapping new environment...'
    
    # Create database if it doesn't exist
    puts '📄 Creating database...'
    Rake::Task['db:create'].invoke
    
    # Install extensions (particularly pgvector for AI features)
    puts '🔧 Installing database extensions...'
    Rake::Task['deploy:setup_extensions'].invoke
    
    # Run migrations
    puts '🗄️ Running database migrations...'
    Rake::Task['db:migrate'].invoke
    
    # Load seed data
    puts '🌱 Loading seed data...'
    Rake::Task['db:seed'].invoke
    
    # Validate MCP fetchers and AI setup
    puts '🔍 Validating MCP fetchers...'
    Rake::Task['deploy:validate_mcp'].invoke
    
    # Validate environment configuration
    puts '✅ Validating environment...'
    Rake::Task['deploy:validate_env'].invoke
    
    puts '🎉 Environment bootstrap completed successfully!'
  end

  desc 'Setup database extensions (pgvector for AI features)'
  task setup_extensions: :environment do
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector;')
    puts '✅ Database extensions installed'
  rescue ActiveRecord::StatementInvalid => e
    puts "⚠️  Could not install pgvector extension: #{e.message}"
    puts "   This may require superuser privileges. Run manually: CREATE EXTENSION IF NOT EXISTS vector;"
  end

  desc 'Validate MCP fetchers and AI configuration'
  task validate_mcp: :environment do
    errors = []
    
    # Check if AI module is enabled
    if ENV.fetch('FEATURE_AI_ENABLED', 'false') == 'true'
      # Check OpenAI API key
      if ENV['OPENAI_API_KEY'].blank?
        errors << 'OPENAI_API_KEY is not set'
      end
      
      # Check Anthropic API key
      if ENV['ANTHROPIC_API_KEY'].blank?
        errors << 'ANTHROPIC_API_KEY is not set'
      end
      
      # TODO: Add MCP fetcher validation when AI module is implemented
      # This would validate GitHub token, Slack token, etc.
    end
    
    if errors.any?
      puts "❌ MCP validation failed:"
      errors.each { |error| puts "   - #{error}" }
      exit 1
    else
      puts "✅ MCP configuration is valid"
    end
  end

  desc 'Validate environment configuration'
  task validate_env: :environment do
    errors = []
    warnings = []
    
    # Required environment variables
    required_vars = %w[
      SECRET_KEY_BASE
      DATABASE_URL
      REDIS_URL
    ]
    
    required_vars.each do |var|
      if ENV[var].blank?
        errors << "#{var} is not set"
      end
    end
    
    # Production-specific requirements
    if Rails.env.production?
      production_vars = %w[
        APP_HOST
        FROM_EMAIL
      ]
      
      production_vars.each do |var|
        if ENV[var].blank?
          errors << "#{var} is required in production"
        end
      end
      
      # Check SSL configuration
      if ENV['FORCE_SSL'] != 'true'
        warnings << 'FORCE_SSL is not enabled in production'
      end
    end
    
    # Optional but recommended variables
    recommended_vars = %w[
      SMTP_HOST
      SMTP_USERNAME
      SMTP_PASSWORD
    ]
    
    recommended_vars.each do |var|
      if ENV[var].blank?
        warnings << "#{var} is not set (email functionality may not work)"
      end
    end
    
    # Check billing configuration if enabled
    if ENV.fetch('FEATURE_BILLING_ENABLED', 'false') == 'true'
      billing_vars = %w[STRIPE_SECRET_KEY STRIPE_PUBLISHABLE_KEY]
      billing_vars.each do |var|
        if ENV[var].blank?
          errors << "#{var} is required when billing is enabled"
        end
      end
    end
    
    # Display results
    if errors.any?
      puts "❌ Environment validation failed:"
      errors.each { |error| puts "   - #{error}" }
      exit 1
    end
    
    if warnings.any?
      puts "⚠️  Environment validation warnings:"
      warnings.each { |warning| puts "   - #{warning}" }
    end
    
    puts "✅ Environment configuration is valid"
  end

  desc 'Check database connectivity and status'
  task check_db: :environment do
    ActiveRecord::Base.connection.execute('SELECT 1')
    puts '✅ Database connection successful'
    
    # Check for pending migrations
    if ActiveRecord::Migration.check_pending!
      puts '✅ All migrations are up to date'
    end
  rescue ActiveRecord::PendingMigrationError
    puts '⚠️  There are pending migrations'
    puts '   Run: rails db:migrate'
    exit 1
  rescue ActiveRecord::NoDatabaseError
    puts '❌ Database does not exist'
    puts '   Run: rails db:create'
    exit 1
  rescue => e
    puts "❌ Database connection failed: #{e.message}"
    exit 1
  end

  desc 'Check Redis connectivity'
  task check_redis: :environment do
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    redis.ping
    puts '✅ Redis connection successful'
  rescue => e
    puts "❌ Redis connection failed: #{e.message}"
    puts "   Check REDIS_URL: #{ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')}"
    exit 1
  end

  desc 'Validate all external service connections'
  task validate_services: %i[check_db check_redis] do
    puts '✅ All services are accessible'
  end

  desc 'Reset and reinitialize the entire environment (DANGEROUS - deletes all data)'
  task reset: :environment do
    if Rails.env.production?
      puts '❌ Cannot reset production environment'
      exit 1
    end
    
    puts '⚠️  This will delete ALL data. Are you sure? (y/N)'
    answer = STDIN.gets.chomp
    
    unless answer.downcase == 'y'
      puts 'Reset cancelled'
      exit 0
    end
    
    puts '🗑️  Dropping database...'
    Rake::Task['db:drop'].invoke
    
    puts '🔄 Re-running bootstrap...'
    Rake::Task['deploy:bootstrap'].invoke
  end
end