# frozen_string_literal: true

# Synth Docs module installer for the Rails SaaS starter template.
# This module creates documentation generation and management tools.

say_status :docs, "Installing documentation module with generators and tools"

# Add documentation gems
add_gem 'yard', '~> 0.9', group: :development
add_gem 'redcarpet', '~> 3.6', group: :development
add_gem 'rouge', '~> 4.4', group: :development

after_bundle do
  # Create YARD configuration
  create_file '.yardopts', <<~'OPTS'
    --markup markdown
    --output-dir docs/api
    --readme README.md
    --files CHANGELOG.md,LICENSE
    --exclude spec/**/*
    --exclude test/**/*
    --exclude config/**/*
    --exclude db/**/*
    --exclude vendor/**/*
    app/**/*.rb
    lib/**/*.rb
  OPTS

  # Create documentation generator service
  create_file 'app/services/documentation_generator.rb', <<~'RUBY'
    class DocumentationGenerator
      attr_reader :output_dir

      def initialize(output_dir = 'docs')
        @output_dir = output_dir
      end

      def generate_all
        ensure_output_directory
        
        generate_api_docs
        generate_module_docs
        generate_setup_guide
        generate_deployment_guide
        generate_changelog
        
        puts "📚 Documentation generated in #{output_dir}/"
      end

      def generate_api_docs
        return unless defined?(Api::BaseController)
        
        puts "📖 Generating API documentation..."
        
        api_docs = {
          openapi: "3.0.1",
          info: {
            title: "#{app_name} API",
            version: "1.0.0",
            description: "REST API for #{app_name}"
          },
          servers: [
            { url: "https://#{app_domain}/api", description: "Production" },
            { url: "http://localhost:3000/api", description: "Development" }
          ],
          paths: generate_api_paths,
          components: {
            securitySchemes: {
              bearerAuth: {
                type: "http",
                scheme: "bearer"
              }
            }
          }
        }

        File.write("#{output_dir}/api_specification.json", JSON.pretty_generate(api_docs))
        puts "✅ API documentation generated"
      end

      def generate_module_docs
        puts "📖 Generating module documentation..."
        
        modules_path = Rails.root.join('lib/templates/synth')
        return unless Dir.exist?(modules_path)

        module_index = ["# Synth Modules\n\n"]
        module_index << "This application uses the following Synth modules:\n\n"

        Dir.children(modules_path).sort.each do |module_name|
          module_dir = modules_path.join(module_name)
          next unless File.directory?(module_dir)

          readme_path = module_dir.join('README.md')
          version_path = module_dir.join('VERSION')
          
          if File.exist?(readme_path)
            version = File.exist?(version_path) ? File.read(version_path).strip : 'Unknown'
            module_index << "## #{module_name.titleize} (v#{version})\n\n"
            
            # Copy module README to docs
            readme_content = File.read(readme_path)
            File.write("#{output_dir}/modules/#{module_name}.md", readme_content)
            
            # Add summary to index
            description = extract_description_from_readme(readme_content)
            module_index << "#{description}\n\n"
            module_index << "[📖 Full Documentation](modules/#{module_name}.md)\n\n"
          end
        end

        FileUtils.mkdir_p("#{output_dir}/modules")
        File.write("#{output_dir}/modules/README.md", module_index.join)
        puts "✅ Module documentation generated"
      end

      def generate_setup_guide
        puts "📖 Generating setup guide..."
        
        setup_guide = <<~'MARKDOWN'
          # Setup Guide

          This guide walks you through setting up your Rails SaaS application.

          ## Prerequisites

          - Ruby 3.3.0 or later
          - Node.js 18 or later  
          - PostgreSQL 14 or later with pgvector extension
          - Redis 6 or later

          ## Installation

          1. **Clone the repository:**
             ```bash
             git clone <your-repo-url>
             cd <your-app>
             ```

          2. **Install dependencies:**
             ```bash
             bundle install
             yarn install
             ```

          3. **Setup the database:**
             ```bash
             rails db:create
             rails db:migrate
             rails db:seed
             ```

          4. **Configure environment variables:**
             ```bash
             cp .env.example .env
             # Edit .env with your credentials
             ```

          5. **Start the development server:**
             ```bash
             bin/dev
             ```

          ## Adding Modules

          Use the Synth CLI to add features to your application:

          ```bash
          # List available modules
          bin/synth list

          # Add authentication
          bin/synth add auth

          # Add billing with Stripe
          bin/synth add billing

          # Add AI capabilities
          bin/synth add ai
          ```

          ## Configuration

          ### Database Setup
          Your application requires PostgreSQL with the pgvector extension for AI features:

          ```sql
          CREATE EXTENSION IF NOT EXISTS pgvector;
          ```

          ### Redis Setup
          Redis is used for caching, sessions, and background job processing.

          ### Environment Variables
          Copy `.env.example` to `.env` and configure:

          - `DATABASE_URL` - PostgreSQL connection string
          - `REDIS_URL` - Redis connection string
          - `RAILS_MASTER_KEY` - Rails credentials encryption key

          ## Testing

          Run the test suite:

          ```bash
          # Full test suite
          bundle exec rspec

          # Specific module tests
          bin/synth test auth
          ```

          ## Development Workflow

          1. Create a feature branch
          2. Add or modify modules using `bin/synth`
          3. Write tests for your changes
          4. Run the test suite
          5. Submit a pull request

        MARKDOWN

        File.write("#{output_dir}/setup.md", setup_guide)
        puts "✅ Setup guide generated"
      end

      def generate_deployment_guide
        puts "📖 Generating deployment guide..."
        
        deployment_guide = <<~'MARKDOWN'
          # Deployment Guide

          This application can be deployed to multiple platforms using the deploy module.

          ## Quick Start

          1. **Install the deploy module:**
             ```bash
             bin/synth add deploy
             ```

          2. **Choose your platform and follow the guide below.**

          ## Deployment Platforms

          ### Fly.io (Recommended)

          1. **Install Fly CLI:**
             ```bash
             curl -L https://fly.io/install.sh | sh
             ```

          2. **Initialize your app:**
             ```bash
             fly launch --no-deploy
             ```

          3. **Set up database:**
             ```bash
             fly postgres create --name myapp-db
             fly postgres attach myapp-db
             ```

          4. **Configure secrets:**
             ```bash
             fly secrets set RAILS_MASTER_KEY=$(rails credentials:show | grep secret_key_base | cut -d' ' -f2)
             ```

          5. **Deploy:**
             ```bash
             bin/deploy-fly
             ```

          ### Render

          1. **Connect your GitHub repository to Render**
          2. **Create a new Web Service**
          3. **Use the provided `render.yaml` configuration**
          4. **Set environment variables in Render dashboard**

          ### Kamal (Self-hosted)

          1. **Install Kamal:**
             ```bash
             gem install kamal
             ```

          2. **Configure your servers in `config/deploy.yml`**

          3. **Setup infrastructure:**
             ```bash
             bin/deploy-kamal setup
             ```

          4. **Deploy:**
             ```bash
             bin/deploy-kamal
             ```

          ## Environment Configuration

          ### Required Environment Variables

          All deployments require these environment variables:

          - `RAILS_MASTER_KEY` - Rails credentials encryption key
          - `DATABASE_URL` - PostgreSQL connection string
          - `REDIS_URL` - Redis connection string

          ### Optional Environment Variables

          Depending on your modules:

          - `OPENAI_API_KEY` - OpenAI API key (AI module)
          - `STRIPE_SECRET_KEY` - Stripe secret key (billing module)
          - `GITHUB_TOKEN` - GitHub API token (integrations)

          ## Post-Deployment

          1. **Run database migrations:**
             ```bash
             # Platform-specific commands
             fly ssh console -C "rails db:migrate"
             ```

          2. **Verify deployment:**
             ```bash
             curl https://your-app.fly.dev/health
             ```

          3. **Monitor logs:**
             ```bash
             fly logs
             ```

        MARKDOWN

        File.write("#{output_dir}/deployment.md", deployment_guide)
        puts "✅ Deployment guide generated"
      end

      def generate_changelog
        puts "📖 Generating changelog..."
        
        changelog = <<~'MARKDOWN'
          # Changelog

          All notable changes to this project will be documented in this file.

          The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
          and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

          ## [Unreleased]

          ### Added
          - Initial project setup with Rails SaaS Starter Template
          - Synth CLI for modular feature management

          ### Changed

          ### Deprecated

          ### Removed

          ### Fixed

          ### Security

          ## [1.0.0] - #{Date.current.strftime('%Y-%m-%d')}

          ### Added
          - Initial release
          - Core Rails application structure
          - Synth modular architecture
          - Base modules: auth, billing, ai, mcp, cms, admin, deploy, testing, api, docs

        MARKDOWN

        File.write("#{output_dir}/CHANGELOG.md", changelog)
        puts "✅ Changelog generated"
      end

      private

      def ensure_output_directory
        FileUtils.mkdir_p(output_dir)
      end

      def app_name
        Rails.application.class.name.split('::').first
      end

      def app_domain
        'your-app.com' # This could be configured
      end

      def generate_api_paths
        # This would introspect your API controllers and generate OpenAPI paths
        # For now, return a basic structure
        {
          "/v1/users" => {
            "get" => {
              "summary" => "List users",
              "security" => [{ "bearerAuth" => [] }]
            }
          }
        }
      end

      def extract_description_from_readme(content)
        lines = content.split("\n")
        # Find the first paragraph after the title
        description_start = lines.find_index { |line| line.strip.length > 0 && !line.start_with?('#') }
        return "No description available." unless description_start

        description = []
        lines[description_start..-1].each do |line|
          break if line.strip.empty? || line.start_with?('#')
          description << line.strip
        end

        description.join(' ').truncate(200)
      end
    end
  RUBY

  # Create documentation Rake task
  create_file 'lib/tasks/docs.rake', <<~'RUBY'
    namespace :docs do
      desc "Generate all documentation"
      task generate: :environment do
        DocumentationGenerator.new.generate_all
      end

      desc "Generate API documentation"
      task api: :environment do
        DocumentationGenerator.new.generate_api_docs
      end

      desc "Generate module documentation"
      task modules: :environment do
        DocumentationGenerator.new.generate_module_docs
      end

      desc "Start documentation server"
      task serve: :environment do
        require 'webrick'
        
        docs_dir = Rails.root.join('docs')
        
        unless Dir.exist?(docs_dir)
          puts "📚 Generating documentation first..."
          Rake::Task['docs:generate'].invoke
        end

        puts "🌐 Starting documentation server at http://localhost:8080"
        puts "📖 Press Ctrl+C to stop"
        
        server = WEBrick::HTTPServer.new(
          Port: 8080,
          DocumentRoot: docs_dir,
          DirectoryIndex: ['index.html', 'README.md']
        )

        trap('INT') { server.shutdown }
        server.start
      end
    end
  RUBY

  # Create documentation index page
  create_file 'docs/index.html', <<~'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Documentation - <%= Rails.application.class.name.split('::').first %></title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                max-width: 1200px;
                margin: 0 auto;
                padding: 2rem;
                background: #f8fafc;
            }
            .header {
                text-align: center;
                margin-bottom: 3rem;
                padding: 2rem;
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .docs-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 2rem;
                margin-bottom: 3rem;
            }
            .doc-card {
                background: white;
                padding: 2rem;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                transition: transform 0.2s;
            }
            .doc-card:hover {
                transform: translateY(-4px);
            }
            .doc-card h3 {
                margin-top: 0;
                color: #2563eb;
            }
            .doc-card a {
                color: #2563eb;
                text-decoration: none;
                font-weight: 500;
            }
            .doc-card a:hover {
                text-decoration: underline;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>📚 Documentation Portal</h1>
            <p>Welcome to your Rails SaaS application documentation</p>
        </div>

        <div class="docs-grid">
            <div class="doc-card">
                <h3>🚀 Setup Guide</h3>
                <p>Get started with installing and configuring your application.</p>
                <a href="setup.md">View Setup Guide →</a>
            </div>

            <div class="doc-card">
                <h3>🧩 Modules</h3>
                <p>Learn about available Synth modules and their features.</p>
                <a href="modules/README.md">Browse Modules →</a>
            </div>

            <div class="doc-card">
                <h3>🚀 Deployment</h3>
                <p>Deploy your application to Fly.io, Render, or self-hosted servers.</p>
                <a href="deployment.md">Deployment Guide →</a>
            </div>

            <div class="doc-card">
                <h3>📖 API Reference</h3>
                <p>Explore the REST API endpoints and authentication.</p>
                <a href="api_specification.json">API Specification →</a>
            </div>

            <div class="doc-card">
                <h3>📝 Changelog</h3>
                <p>Track changes and updates to your application.</p>
                <a href="CHANGELOG.md">View Changelog →</a>
            </div>

            <div class="doc-card">
                <h3>🔧 Code Documentation</h3>
                <p>Generated documentation from your Ruby code.</p>
                <a href="api/index.html">YARD Docs →</a>
            </div>
        </div>

        <footer style="text-align: center; color: #6b7280; margin-top: 3rem;">
            <p>Generated by Synth Docs Module</p>
        </footer>
    </body>
    </html>
  HTML

  say_status :docs, "Documentation module installed. Next steps:"
  say_status :docs, "1. Run rails docs:generate to create documentation"
  say_status :docs, "2. Use rails docs:serve to start a local docs server"
  say_status :docs, "3. Customize documentation templates as needed"
  say_status :docs, "4. Set up automated doc generation in CI/CD"
end