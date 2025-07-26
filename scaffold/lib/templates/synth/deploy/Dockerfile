# Multi-stage Dockerfile for Rails SaaS Starter Template
ARG RUBY_VERSION=3.3.0
FROM ruby:$RUBY_VERSION-slim AS base

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      git \
      libpq-dev \
      libvips \
      pkg-config \
      curl \
      && rm -rf /var/lib/apt/lists/*

# Install Node.js and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /rails

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 && \
    bundle install

# Install JavaScript dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_for_assets
RUN bin/rails assets:precompile && \
    rm -rf node_modules

# Production stage
FROM ruby:$RUBY_VERSION-slim AS production

# Install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      libpq5 \
      libvips \
      curl \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# Copy built application from base stage
COPY --from=base /usr/local/bundle /usr/local/bundle
COPY --from=base /rails /rails

# Create non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Set ownership and permissions
RUN chown -R rails:rails /rails
USER rails:rails

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]