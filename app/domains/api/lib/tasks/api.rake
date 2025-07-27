# frozen_string_literal: true

namespace :api do
  desc 'Generate OpenAPI schema from RSpec tests'
  task generate_schema: :environment do
    require 'rswag/specs/rake_task'
    Rake::Task['rswag:specs:swaggerize'].invoke
    puts "✅ OpenAPI schema generated at swagger/v1/swagger.yaml"
  end

  desc 'Validate that OpenAPI schema is up to date'
  task validate_schema: :environment do
    require 'digest'
    
    schema_path = Rails.root.join('swagger', 'v1', 'swagger.yaml')
    
    unless schema_path.exist?
      puts "❌ OpenAPI schema not found. Run 'rake api:generate_schema' first."
      exit 1
    end
    
    # Store current schema
    current_schema = File.read(schema_path)
    current_checksum = Digest::SHA256.hexdigest(current_schema)
    
    # Generate new schema
    require 'rswag/specs/rake_task'
    Rake::Task['rswag:specs:swaggerize'].invoke
    
    # Compare with current
    new_schema = File.read(schema_path)
    new_checksum = Digest::SHA256.hexdigest(new_schema)
    
    if current_checksum != new_checksum
      puts "❌ OpenAPI schema is out of date. Run 'rake api:generate_schema' to update."
      exit 1
    else
      puts "✅ OpenAPI schema is up to date."
    end
  end

  desc 'Validate API endpoints against OpenAPI specification'
  task validate_endpoints: :environment do
    # This task validates that all API routes have corresponding OpenAPI specs
    puts "🔍 Validating API endpoints against specification..."
    
    api_routes = Rails.application.routes.routes.select do |route|
      route.path.spec.to_s.start_with?('/api/') && 
      !route.path.spec.to_s.include?('api-docs')
    end
    
    puts "📊 Found #{api_routes.count} API routes:"
    api_routes.each do |route|
      method = route.verb.source.gsub(/[\^\$]/, '')
      path = route.path.spec.to_s.gsub(/\(\.\w+\)/, '') # Remove format specifiers
      puts "  #{method.ljust(6)} #{path}"
    end
    
    # Check if swagger spec exists
    schema_path = Rails.root.join('swagger', 'v1', 'swagger.yaml')
    if schema_path.exist?
      require 'yaml'
      spec = YAML.load_file(schema_path)
      documented_paths = spec['paths']&.keys || []
      
      puts "\n📋 OpenAPI documented paths:"
      documented_paths.each { |path| puts "  #{path}" }
      
      undocumented = api_routes.reject do |route|
        path = route.path.spec.to_s.gsub(/\(\.\w+\)/, '').gsub(/:(\w+)/, '{\1}')
        documented_paths.include?(path)
      end
      
      if undocumented.any?
        puts "\n⚠️  Undocumented API routes found:"
        undocumented.each do |route|
          method = route.verb.source.gsub(/[\^\$]/, '')
          path = route.path.spec.to_s.gsub(/\(\.\w+\)/, '')
          puts "  #{method.ljust(6)} #{path}"
        end
        puts "\n💡 Add RSpec request specs for these routes to generate documentation."
      else
        puts "\n✅ All API routes are documented in OpenAPI specification."
      end
    else
      puts "\n⚠️  OpenAPI schema not found. Run 'rake api:generate_schema' after adding request specs."
      puts "📝 Create RSpec request specs in spec/requests/api/ to generate documentation."
    end
  end
end