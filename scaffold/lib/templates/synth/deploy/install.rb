# frozen_string_literal: true

# Synth Deploy module installer for the Rails SaaS starter template.
# This module creates deployment configurations for Fly.io, Render, and Kamal.

say_status :deploy, "Installing deployment configurations for multiple platforms"

# Add deployment gems
add_gem 'kamal', '~> 2.4', group: :development
add_gem 'dockerfile-rails', '~> 1.7', group: :development

after_bundle do
  # Create Fly.io configuration
  create_file 'fly.toml', <<~'TOML'
    app = "your-app-name"
    primary_region = "iad"

    [build]

    [http_service]
      internal_port = 3000
      force_https = true
      auto_stop_machines = "stop"
      auto_start_machines = true
      min_machines_running = 1
      processes = ["app"]

    [[vm]]
      memory = "1gb"
      cpu_kind = "shared"
      cpus = 1

    [env]
      RAILS_ENV = "production"
      BUNDLE_WITHOUT = "development:test"

    [[statics]]
      guest_path = "/rails/public"
      url_prefix = "/"
  TOML

  # Create Dockerfile
  create_file 'Dockerfile', <<~'DOCKERFILE'
    # syntax = docker/dockerfile:1

    ARG RUBY_VERSION=3.3.0
    FROM ruby:$RUBY_VERSION-slim as base

    WORKDIR /rails

    # Set production environment
    ENV RAILS_ENV="production" \
        BUNDLE_WITHOUT="development:test" \
        BUNDLE_DEPLOYMENT="1"

    # Install packages needed to build gems and for runtime
    RUN apt-get update -qq && \
        apt-get install --no-install-recommends -y \
        build-essential \
        git \
        libpq-dev \
        libvips \
        pkg-config \
        postgresql-client && \
        rm -rf /var/lib/apt/lists /var/cache/apt/archives

    # Install application gems
    COPY Gemfile Gemfile.lock ./
    RUN bundle install && \
        bundle exec bootsnap precompile --gemfile && \
        rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

    # Copy application code
    COPY . .

    # Precompile bootsnap code for faster boot times
    RUN bundle exec bootsnap precompile app/ lib/

    # Precompiling assets for production without requiring secret RAILS_MASTER_KEY
    RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

    # Create a non-root user to run the application
    RUN groupadd --system --gid 1000 rails && \
        useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
        chown -R 1000:1000 db log storage tmp
    USER 1000:1000

    # Entrypoint prepares the database
    ENTRYPOINT ["/rails/bin/docker-entrypoint"]

    # Start the server by default
    EXPOSE 3000
    CMD ["./bin/rails", "server"]
  DOCKERFILE

  # Create Docker entrypoint
  create_file 'bin/docker-entrypoint', <<~'BASH'
    #!/bin/bash -e

    # If running the rails server then create or migrate existing database
    if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
      ./bin/rails db:prepare
    fi

    exec "${@}"
  BASH

  # Make entrypoint executable
  run 'chmod +x bin/docker-entrypoint'

  # Create Kamal configuration
  create_file 'config/deploy.yml', <<~'YAML'
    service: your-app-name
    image: your-registry/your-app-name

    servers:
      web:
        hosts:
          - your-server-ip
        options:
          "add-host": "host.docker.internal:host-gateway"

    registry:
      server: registry.digitalocean.com
      username: your-username
      password:
        - KAMAL_REGISTRY_PASSWORD

    env:
      clear:
        RAILS_ENV: production
      secret:
        - RAILS_MASTER_KEY
        - DATABASE_URL
        - REDIS_URL

    accessories:
      db:
        image: postgres:15
        host: your-server-ip
        env:
          clear:
            POSTGRES_USER: your-app
            POSTGRES_DB: your-app_production
          secret:
            - POSTGRES_PASSWORD
        directories:
          - data:/var/lib/postgresql/data

      redis:
        image: redis:7
        host: your-server-ip
        directories:
          - data:/data

    traefik:
      options:
        publish:
          - "443:443"
        volume:
          - "/letsencrypt/acme.json:/letsencrypt/acme.json"
      args:
        entryPoints.web.address: ":80"
        entryPoints.websecure.address: ":443"
        certificatesResolvers.letsencrypt.acme.email: "your-email@example.com"
        certificatesResolvers.letsencrypt.acme.storage: "/letsencrypt/acme.json"
        certificatesResolvers.letsencrypt.acme.httpchallenge: true
        certificatesResolvers.letsencrypt.acme.httpchallenge.entrypoint: web
  YAML

  # Create Render configuration
  create_file 'render.yaml', <<~'YAML'
    services:
      - type: web
        name: your-app-name
        env: ruby
        plan: starter
        buildCommand: "./bin/render-build.sh"
        startCommand: "bundle exec puma -C config/puma.rb"
        envVars:
          - key: RAILS_ENV
            value: production
          - key: BUNDLE_WITHOUT
            value: development:test
          - key: RAILS_MASTER_KEY
            sync: false
          - key: DATABASE_URL
            fromDatabase:
              name: your-app-name-db
              property: connectionString
          - key: REDIS_URL
            fromService:
              type: redis
              name: your-app-name-redis
              property: connectionString

    databases:
      - name: your-app-name-db
        plan: starter
        databaseName: your_app_production
        user: your_app

    services:
      - type: redis
        name: your-app-name-redis
        plan: starter
  YAML

  # Create Render build script
  create_file 'bin/render-build.sh', <<~'BASH'
    #!/usr/bin/env bash
    # exit on error
    set -o errexit

    bundle install
    bundle exec rails assets:precompile
    bundle exec rails assets:clean
    bundle exec rails db:migrate
  BASH

  # Make build script executable
  run 'chmod +x bin/render-build.sh'

  # Create GitHub Actions deployment workflow
  create_file '.github/workflows/deploy.yml', <<~'YAML'
    name: Deploy

    on:
      push:
        branches: [ main ]

    jobs:
      deploy:
        runs-on: ubuntu-latest
        
        steps:
          - uses: actions/checkout@v4
          
          - name: Deploy to Fly.io
            uses: superfly/flyctl-actions/setup-flyctl@master
          
          - run: flyctl deploy --remote-only
            env:
              FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      deploy-kamal:
        runs-on: ubuntu-latest
        if: false  # Enable when ready to use Kamal
        
        steps:
          - uses: actions/checkout@v4
          
          - name: Set up Ruby
            uses: ruby/setup-ruby@v1
            with:
              bundler-cache: true
          
          - name: Deploy with Kamal
            run: bundle exec kamal deploy
            env:
              KAMAL_REGISTRY_PASSWORD: ${{ secrets.KAMAL_REGISTRY_PASSWORD }}
              RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
  YAML

  # Create deployment scripts
  create_file 'bin/deploy-fly', <<~'BASH'
    #!/usr/bin/env bash
    # Deploy to Fly.io

    echo "🚀 Deploying to Fly.io..."

    # Check if fly CLI is installed
    if ! command -v fly &> /dev/null; then
        echo "❌ Fly CLI not found. Install it first:"
        echo "curl -L https://fly.io/install.sh | sh"
        exit 1
    fi

    # Deploy
    fly deploy

    echo "✅ Deployment complete!"
    echo "🌐 App URL: https://$(fly info -j | jq -r '.Hostname')"
  BASH

  create_file 'bin/deploy-render', <<~'BASH'
    #!/usr/bin/env bash
    # Deploy to Render

    echo "🚀 Deploying to Render..."
    echo "Push to main branch to trigger automatic deployment"
    echo "Or use Render CLI: render deploy"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Current branch: $(git branch --show-current)"
        echo "Latest commit: $(git log -1 --oneline)"
    fi
  BASH

  create_file 'bin/deploy-kamal', <<~'BASH'
    #!/usr/bin/env bash
    # Deploy with Kamal

    echo "🚀 Deploying with Kamal..."

    # Check if kamal is available
    if ! command -v kamal &> /dev/null; then
        echo "❌ Kamal not found. Install it first:"
        echo "gem install kamal"
        exit 1
    fi

    # Setup if first deployment
    if [ "$1" = "setup" ]; then
        echo "🔧 Setting up Kamal..."
        kamal setup
    else
        echo "📦 Deploying application..."
        kamal deploy
    fi

    echo "✅ Deployment complete!"
  BASH

  # Make deploy scripts executable
  run 'chmod +x bin/deploy-fly bin/deploy-render bin/deploy-kamal'

  say_status :deploy, "Deploy module installed. Next steps:"
  say_status :deploy, "1. Choose your deployment platform (Fly.io, Render, or Kamal)"
  say_status :deploy, "2. Update configuration files with your app details"
  say_status :deploy, "3. Set up secrets and environment variables"
  say_status :deploy, "4. Run the appropriate deploy script"
end