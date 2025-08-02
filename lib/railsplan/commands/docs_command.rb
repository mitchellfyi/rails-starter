# frozen_string_literal: true

require "railsplan/commands/base_command"
require "railsplan/context_manager"
require "railsplan/ai_config"
require "railsplan"

module RailsPlan
  module Commands
    # Command for auto-generating documentation
    class DocsCommand < BaseCommand
      SUPPORTED_DOC_TYPES = %w[readme schema api onboarding ai_usage].freeze
      
      def initialize(verbose: false)
        super
        @context_manager = ContextManager.new
      end
      
      def execute(docs_type = nil, options = {})
        unless options[:silent]
          puts "📚 Generating documentation for Rails application..."
          puts "📝 Type: #{docs_type || 'all'}" if docs_type
          puts ""
        end
        
        unless rails_app?
          puts "❌ Not in a Rails application directory" unless options[:silent]
          return false
        end
        
        # Determine which docs to generate
        docs_to_generate = if docs_type
          validate_docs_type(docs_type, options)
        else
          SUPPORTED_DOC_TYPES
        end
        
        return false if docs_to_generate.nil?
        
        # Check existing files if not forcing overwrite
        unless options[:overwrite]
          existing_files = check_existing_files(docs_to_generate)
          if existing_files.any? && !confirm_overwrite(existing_files, options)
            puts "❌ Documentation generation cancelled" unless options[:silent]
            return false
          end
        end
        
        begin
          # Load or extract context for AI generation
          ensure_context_available(options)
          
          # Generate documentation
          results = generate_documentation(docs_to_generate, options)
          
          if options[:dry_run]
            show_dry_run_results(results, options)
          else
            write_documentation_files(results, options)
            show_success_message(results, options)
          end
          
          true
          
        rescue RailsPlan::Error => e
          puts "❌ Documentation generation failed: #{e.message}" unless options[:silent]
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        rescue StandardError => e
          puts "❌ Unexpected error during documentation generation: #{e.message}" unless options[:silent]
          log_verbose(e.backtrace.join("\n")) if verbose
          false
        end
      end
      
      private
      
      def rails_app?
        File.exist?("config/application.rb") || File.exist?("Gemfile")
      end
      
      def validate_docs_type(docs_type, options)
        unless SUPPORTED_DOC_TYPES.include?(docs_type)
          unless options[:silent]
            puts "❌ Unsupported documentation type: #{docs_type}"
            puts "Supported types: #{SUPPORTED_DOC_TYPES.join(', ')}"
          end
          return nil
        end
        [docs_type]
      end
      
      def check_existing_files(docs_types)
        existing = []
        docs_types.each do |type|
          file_path = get_file_path_for_type(type)
          existing << file_path if File.exist?(file_path)
        end
        existing
      end
      
      def get_file_path_for_type(type)
        case type
        when 'readme'
          'README.md'
        when 'schema'
          'docs/schema.md'
        when 'api'
          'docs/api.md'
        when 'onboarding'
          'docs/onboarding.md'
        when 'ai_usage'
          'docs/ai_usage.md'
        end
      end
      
      def confirm_overwrite(existing_files, options)
        return true if options[:force] || options[:silent]
        
        require "tty-prompt"
        prompt = TTY::Prompt.new
        
        puts "⚠️  The following documentation files already exist:"
        existing_files.each { |file| puts "  - #{file}" }
        puts ""
        
        prompt.yes?("Do you want to overwrite them?")
      end
      
      def ensure_context_available(options)
        if !@context_manager.load_context || @context_manager.context_stale?
          puts "🔍 Extracting application context..." unless options[:silent]
          @context_manager.extract_context
          puts "✅ Context updated" unless options[:silent]
          puts "" unless options[:silent]
        end
      end
      
      def generate_documentation(docs_types, options)
        results = {}
        
        docs_types.each do |type|
          puts "📄 Generating #{type} documentation..." unless options[:silent]
          
          content = generate_doc_content(type, options)
          file_path = get_file_path_for_type(type)
          
          results[type] = {
            file_path: file_path,
            content: content
          }
        end
        
        results
      end
      
      def generate_doc_content(type, options)
        case type
        when 'readme'
          generate_readme_content(options)
        when 'schema'
          generate_schema_content(options)
        when 'api'
          generate_api_content(options)
        when 'onboarding'
          generate_onboarding_content(options)
        when 'ai_usage'
          generate_ai_usage_content(options)
        end
      end
      
      def generate_readme_content(options)
        app_name = get_app_name
        context = @context_manager.load_context || {}
        
        # Analyze the application structure
        tech_stack = analyze_tech_stack
        key_features = analyze_key_features(context)
        
        +<<~MARKDOWN  # Make string mutable
          # #{app_name}

          ## Overview

          #{app_name} is a Rails application built with modern development practices and AI-native features.

          ## Tech Stack

          #{format_tech_stack(tech_stack)}

          ## Features

          #{format_features(key_features)}

          ## Getting Started

          ### Prerequisites

          - Ruby #{get_ruby_version}
          - Rails #{get_rails_version}
          - Node.js (for asset compilation)
          - PostgreSQL or SQLite (database)

          ### Installation

          1. Clone the repository:
             ```bash
             git clone <repository-url>
             cd #{app_name.downcase.gsub(/\s+/, '-')}
             ```

          2. Install dependencies:
             ```bash
             bundle install
             npm install
             ```

          3. Setup the database:
             ```bash
             bin/rails db:create
             bin/rails db:migrate
             bin/rails db:seed
             ```

          4. Start the development server:
             ```bash
             bin/rails server
             ```

          ## Development Commands

          - `bin/rails server` - Start the development server
          - `bin/rails console` - Start the Rails console
          - `bin/rails test` - Run the test suite
          - `bin/rails db:migrate` - Run database migrations
          - `bin/rails db:seed` - Seed the database with sample data

          ## Documentation

          - [Database Schema](docs/schema.md) - Database structure and relationships
          - [API Documentation](docs/api.md) - API endpoints and usage
          - [Developer Onboarding](docs/onboarding.md) - Getting started as a developer
          - [AI Usage Guide](docs/ai_usage.md) - AI features and configuration

          ## Contributing

          1. Fork the repository
          2. Create your feature branch (`git checkout -b feature/amazing-feature`)
          3. Commit your changes (`git commit -m 'Add some amazing feature'`)
          4. Push to the branch (`git push origin feature/amazing-feature`)
          5. Open a Pull Request

          ## License

          This project is licensed under the MIT License.
        MARKDOWN
      end
      
      def generate_schema_content(options)
        context = @context_manager.load_context || {}
        models = context.dig('models') || []
        
        content = +<<~MARKDOWN  # Make string mutable
          # Database Schema

          This document describes the database schema for the application.

          ## Models Overview

        MARKDOWN
        
        if models.empty?
          content << "\nNo models found in the application.\n"
        else
          content << format_models_overview(models)
          content << "\n## Model Details\n\n"
          content << format_model_details(models)
        end
        
        content << "\n## Relationships\n\n"
        content << format_model_relationships(models)
        
        content
      end
      
      def generate_api_content(options)
        context = @context_manager.load_context || {}
        routes = extract_api_routes
        
        +<<~MARKDOWN  # Make string mutable
          # API Documentation

          This document describes the REST API endpoints available in the application.

          ## Base URL

          ```
          Development: http://localhost:3000
          Production: https://your-domain.com
          ```

          ## Authentication

          Most API endpoints require authentication. Include the following header:

          ```
          Authorization: Bearer <your-token>
          ```

          ## Endpoints

          #{format_api_routes(routes)}

          ## Response Format

          All API responses follow this structure:

          ```json
          {
            "data": {},
            "meta": {
              "status": "success",
              "timestamp": "2024-01-01T12:00:00Z"
            }
          }
          ```

          ## Error Handling

          Error responses include:

          ```json
          {
            "error": {
              "code": "ERROR_CODE",
              "message": "Human readable error message"
            },
            "meta": {
              "status": "error",
              "timestamp": "2024-01-01T12:00:00Z"
            }
          }
          ```
        MARKDOWN
      end
      
      def generate_onboarding_content(options)
        tech_stack = analyze_tech_stack
        
        +<<~MARKDOWN  # Make string mutable
          # Developer Onboarding

          Welcome to the development team! This guide will help you get up and running.

          ## Required Tools and Versions

          ### Core Requirements
          - Ruby #{get_ruby_version}
          - Rails #{get_rails_version}
          - Node.js (>= 18.0)
          - npm or yarn

          ### Database
          - PostgreSQL (>= 13) or SQLite 3

          ### Development Tools
          - Git
          - Code editor (VS Code, RubyMine, etc.)
          - Browser with developer tools

          ## Setup Process

          1. **Clone the repository**
             ```bash
             git clone <repository-url>
             cd <project-directory>
             ```

          2. **Install Ruby dependencies**
             ```bash
             bundle install
             ```

          3. **Install Node.js dependencies**
             ```bash
             npm install
             ```

          4. **Setup environment variables**
             ```bash
             cp .env.example .env
             # Edit .env with your configuration
             ```

          5. **Setup the database**
             ```bash
             bin/rails db:create
             bin/rails db:migrate
             bin/rails db:seed
             ```

          6. **Run tests to verify setup**
             ```bash
             bin/rails test
             ```

          7. **Start the development server**
             ```bash
             bin/rails server
             ```

          ## AI Features and Context System

          This application uses RailsPlan's AI-native architecture:

          - **Context Management**: The `.railsplan/` directory contains AI context
          - **AI Code Generation**: Use `railsplan generate` for AI-powered development
          - **Prompt Logging**: All AI interactions are logged for review

          ### AI Configuration

          Configure AI providers in `~/.railsplan/ai.yml`:

          ```yaml
          default:
            provider: openai
            model: gpt-4o
            api_key: <%= ENV['OPENAI_API_KEY'] %>
          ```

          ## Testing Strategy

          ### Running Tests
          - `bin/rails test` - Run all tests
          - `bin/rails test test/models/` - Run model tests
          - `bin/rails test test/controllers/` - Run controller tests

          ### Test Structure
          - Unit tests for models and services
          - Integration tests for controllers
          - System tests for user workflows

          ## Code Style and Conventions

          - Follow Ruby community style guides
          - Use RuboCop for code formatting
          - Write descriptive commit messages
          - Include tests for new features

          ## Common Development Tasks

          ### Adding a New Feature
          1. Create a feature branch
          2. Use `railsplan generate` for AI-assisted development
          3. Write comprehensive tests
          4. Update documentation
          5. Submit a pull request

          ### Database Changes
          1. Generate migration: `bin/rails generate migration`
          2. Run migration: `bin/rails db:migrate`
          3. Update schema documentation: `railsplan generate docs schema`

          ## Troubleshooting

          ### Common Issues
          - **Bundle install fails**: Check Ruby version and dependencies
          - **Database errors**: Ensure database is running and configured
          - **Asset compilation fails**: Check Node.js version and npm packages

          ### Getting Help
          - Check existing documentation
          - Ask team members in Slack/Discord
          - Review pull requests for similar features
          - Use `railsplan doctor` for system diagnostics
        MARKDOWN
      end
      
      def generate_ai_usage_content(options)
        +<<~MARKDOWN  # Make string mutable
          # AI Usage Guide

          This application is built with RailsPlan's AI-native architecture, providing powerful AI-assisted development capabilities.

          ## AI-Powered Features

          ### Code Generation
          Use natural language to generate Rails code:

          ```bash
          railsplan generate "Add a Blog model with title, content, and user association"
          railsplan generate "Create a comment system for blog posts"
          railsplan generate "Add user authentication with devise"
          ```

          ### Documentation Generation
          Keep documentation up-to-date automatically:

          ```bash
          railsplan generate docs              # Generate all documentation
          railsplan generate docs schema       # Update only schema docs
          railsplan generate docs --overwrite  # Force regeneration
          ```

          ## AI Configuration

          ### Provider Setup
          Configure AI providers in `~/.railsplan/ai.yml`:

          ```yaml
          default:
            provider: openai
            model: gpt-4o
            api_key: <%= ENV['OPENAI_API_KEY'] %>
            
          profiles:
            development:
              provider: openai
              model: gpt-3.5-turbo
              api_key: <%= ENV['OPENAI_API_KEY'] %>
              
            production:
              provider: anthropic
              model: claude-3-sonnet
              api_key: <%= ENV['CLAUDE_KEY'] %>
          ```

          ### Environment Variables
          Set these environment variables:

          ```bash
          export OPENAI_API_KEY=your_openai_key
          export CLAUDE_KEY=your_claude_key
          export RAILSPLAN_AI_PROVIDER=openai
          ```

          ### API Key Rotation
          To rotate API keys:

          1. Update environment variables
          2. Update `~/.railsplan/ai.yml`
          3. Test with: `railsplan doctor`

          ## Prompt Management

          ### Prompt Logging
          All AI interactions are logged in `.railsplan/prompts.log`:

          ```
          [2024-01-01T12:00:00Z] PROMPT: Add a Blog model with title and content
          [2024-01-01T12:00:05Z] RESPONSE: Generated blog.rb model with validations
          [2024-01-01T12:00:05Z] FILES: app/models/blog.rb, db/migrate/001_create_blogs.rb
          ```

          ### Prompt Review
          Review generated code before applying:

          ```bash
          railsplan generate "your instruction" --dry-run
          ```

          ### Prompt Templates
          Use consistent prompts for better results:

          - **Models**: "Add a [ModelName] model with [attributes] and [associations]"
          - **Controllers**: "Create a [controller] controller with [actions]"
          - **Features**: "Implement [feature] with [specific requirements]"

          ## Context Management

          ### Application Context
          RailsPlan maintains context in `.railsplan/context.json`:

          ```json
          {
            "models": { /* model definitions */ },
            "routes": { /* API routes */ },
            "controllers": { /* controller info */ },
            "schema_hash": "abc123...",
            "last_updated": "2024-01-01T12:00:00Z"
          }
          ```

          ### Updating Context
          Keep context fresh for better AI results:

          ```bash
          railsplan index  # Extract current application context
          ```

          Context is automatically updated after successful code generation.

          ## Best Practices

          ### Writing Effective Prompts
          - Be specific about requirements
          - Mention existing models and associations
          - Specify testing requirements
          - Include validation and error handling needs

          ### Code Review Process
          1. Generate code with AI
          2. Review the generated files
          3. Test the functionality
          4. Refactor if needed
          5. Commit with descriptive messages

          ### Security Considerations
          - Review all generated code for security issues
          - Validate input handling and sanitization
          - Check authorization and authentication logic
          - Audit database queries for injection risks

          ## Monitoring and Audit

          ### AI Usage Tracking
          Monitor AI usage through:
          - Prompt logs in `.railsplan/prompts.log`
          - Generated file tracking
          - Success/failure rates

          ### Code Quality
          Ensure AI-generated code meets standards:
          - Run tests after generation
          - Use RuboCop for style checking
          - Perform security audits
          - Review for performance issues

          ## Troubleshooting

          ### Common Issues
          - **API key invalid**: Check environment variables and configuration
          - **Context stale**: Run `railsplan index` to refresh
          - **Generation fails**: Review prompt clarity and application state

          ### Getting Help
          - Check `.railsplan/prompts.log` for error details
          - Use `railsplan doctor` for diagnostic information
          - Review existing successful prompts for patterns
        MARKDOWN
      end
      
      def show_dry_run_results(results, options)
        return if options[:silent]
        
        puts "🔍 Dry run results:"
        puts ""
        
        results.each do |type, data|
          puts "📄 Would generate: #{data[:file_path]}"
          puts "   Lines: #{data[:content].lines.count}"
          puts "   Size: #{data[:content].bytesize} bytes"
          puts ""
        end
        
        puts "💡 Use --overwrite to write these files"
      end
      
      def write_documentation_files(results, options)
        puts "📝 Writing documentation files..." unless options[:silent]
        
        results.each do |type, data|
          file_path = data[:file_path]
          content = data[:content]
          
          # Ensure directory exists
          FileUtils.mkdir_p(File.dirname(file_path))
          
          # Log the prompt and response
          log_prompt_and_response(type, content)
          
          # Write the file
          File.write(file_path, content)
          
          puts "  ✅ Created #{file_path}" unless options[:silent]
        end
      end
      
      def show_success_message(results, options)
        return if options[:silent]
        
        puts ""
        puts "✅ Documentation generated successfully!"
        puts ""
        puts "📁 Generated files:"
        results.each do |type, data|
          puts "  - #{data[:file_path]}"
        end
        
        puts ""
        puts "💡 Next steps:"
        puts "  - Review the generated documentation"
        puts "  - Customize content as needed"
        puts "  - Re-run with specific types: railsplan generate docs <type>"
        puts "  - Keep docs updated with: railsplan generate docs --overwrite"
      end
      
      def log_prompt_and_response(type, content)
        timestamp = Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        log_dir = ".railsplan"
        log_file = File.join(log_dir, "prompts.log")
        
        # Ensure .railsplan directory exists
        FileUtils.mkdir_p(log_dir)
        
        # Log the documentation generation
        log_entry = "[#{timestamp}] DOCS_GENERATION: #{type}\n"
        log_entry << "[#{timestamp}] OUTPUT_SIZE: #{content.bytesize} bytes\n"
        log_entry << "[#{timestamp}] OUTPUT_LINES: #{content.lines.count}\n"
        log_entry << "---\n"
        
        File.open(log_file, "a") do |f|
          f.write(log_entry)
        end
      end
      
      # Helper methods for content generation
      
      def get_app_name
        # Try to get from Rails application
        if File.exist?("config/application.rb")
          content = File.read("config/application.rb")
          match = content.match(/module\s+(\w+)/)
          return match[1] if match
        end
        
        # Fallback to directory name
        File.basename(Dir.pwd).split(/[-_]/).map(&:capitalize).join(' ')
      end
      
      def get_ruby_version
        if File.exist?(".ruby-version")
          File.read(".ruby-version").strip
        else
          RUBY_VERSION
        end
      end
      
      def get_rails_version
        if File.exist?("Gemfile.lock")
          content = File.read("Gemfile.lock")
          match = content.match(/rails \(([^)]+)\)/)
          return match[1] if match
        end
        
        "Latest"
      end
      
      def analyze_tech_stack
        stack = {
          "Ruby" => get_ruby_version,
          "Rails" => get_rails_version
        }
        
        # Check Gemfile for common gems
        if File.exist?("Gemfile")
          gemfile_content = File.read("Gemfile")
          
          stack["Database"] = if gemfile_content.include?("pg")
            "PostgreSQL"
          elsif gemfile_content.include?("mysql")
            "MySQL"
          else
            "SQLite"
          end
          
          stack["CSS Framework"] = "Tailwind CSS" if gemfile_content.include?("tailwindcss")
          stack["Authentication"] = "Devise" if gemfile_content.include?("devise")
          stack["Authorization"] = "CanCanCan" if gemfile_content.include?("cancancan")
          stack["Background Jobs"] = "Sidekiq" if gemfile_content.include?("sidekiq")
          stack["API"] = "JSON:API" if gemfile_content.include?("jsonapi")
        end
        
        stack
      end
      
      def analyze_key_features(context)
        features = []
        
        # Analyze models for features - models is an array of model objects
        models = context.dig('models') || []
        user_model = models.find { |model| model['class_name'] == 'User' }
        features << "User Management" if user_model
        features << "Authentication" if user_model && File.exist?("app/models/user.rb")
        
        # Check for common patterns - routes is an array of route objects
        routes = context.dig('routes') || []
        api_routes = routes.select { |route| route['path']&.include?('/api/') }
        features << "API Endpoints" if api_routes.any?
        features << "Admin Interface" if Dir.exist?("app/admin")
        features << "Background Jobs" if Dir.exist?("app/jobs") && Dir.glob("app/jobs/*.rb").any?
        
        # AI-specific features
        features << "AI-Powered Development" if File.exist?(".railsplan/context.json")
        
        features.empty? ? ["Rails Application"] : features
      end
      
      def format_tech_stack(stack)
        stack.map { |tech, version| "- **#{tech}**: #{version}" }.join("\n")
      end
      
      def format_features(features)
        features.map { |feature| "- #{feature}" }.join("\n")
      end
      
      def format_models_overview(models)
        content = +"\n"  # Make string mutable
        models.each do |model_data|
          model_name = model_data['class_name']
          validations = model_data['validations'] || []
          content << "- **#{model_name}**: #{validations.length} validations\n"
        end
        content
      end
      
      def format_model_details(models)
        content = +""  # Make string mutable
        models.each do |model_data|
          model_name = model_data['class_name']
          content << "### #{model_name}\n\n"
          
          validations = model_data['validations'] || []
          if validations.any?
            content << "**Validations:**\n"
            validations.each do |validation|
              content << "- `#{validation['field']}`: #{validation['rules']}\n"
            end
          end
          
          associations = model_data['associations'] || []
          if associations.any?
            content << "\n**Associations:**\n"
            associations.each do |assoc|
              content << "- `#{assoc['type']}` #{assoc['name']}\n"
            end
          end
          
          scopes = model_data['scopes'] || []
          if scopes.any?
            content << "\n**Scopes:**\n"
            scopes.each do |scope|
              content << "- `#{scope['name']}`\n"
            end
          end
          
          content << "\n"
        end
        content
      end
      
      def format_model_relationships(models)
        content = +""  # Make string mutable
        models.each do |model_data|
          model_name = model_data['class_name']
          associations = model_data['associations'] || []
          associations.each do |assoc|
            content << "- #{model_name} `#{assoc['type']}` #{assoc['name']}\n"
          end
        end
        content.empty? ? "No explicit relationships found.\n" : content
      end
      
      def extract_api_routes
        routes = []
        
        # Try to extract from Rails routes
        if File.exist?("config/routes.rb")
          # This is a simplified extraction - in a real implementation,
          # you might want to actually parse the routes or run `rails routes`
          routes_content = File.read("config/routes.rb")
          
          # Look for API namespaces
          if routes_content.include?("namespace :api") || routes_content.include?("scope :api")
            routes << {
              method: "GET",
              path: "/api/v1/users",
              description: "List all users",
              controller: "Api::V1::UsersController"
            }
          end
        end
        
        routes
      end
      
      def format_api_routes(routes)
        return "No API routes found.\n" if routes.empty?
        
        content = +""  # Make string mutable
        routes.each do |route|
          content << "### #{route[:method]} #{route[:path]}\n\n"
          content << "#{route[:description]}\n\n"
          content << "**Controller:** `#{route[:controller]}`\n\n"
        end
        content
      end
    end
  end
end