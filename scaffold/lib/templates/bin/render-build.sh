#!/usr/bin/env bash
# Build script for Render deployment
# This script is referenced in render.yaml

set -o errexit

echo "Installing dependencies..."
bundle install

echo "Installing Node.js dependencies..."
npm install

echo "Precompiling assets..."
bundle exec rails assets:precompile

echo "Creating database if it doesn't exist..."
bundle exec rails db:create DISABLE_DATABASE_ENVIRONMENT_CHECK=1 || true

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Loading seed data..."
bundle exec rails db:seed

echo "Build completed successfully!"