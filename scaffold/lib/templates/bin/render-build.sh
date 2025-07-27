#!/usr/bin/env bash
# Build script for Render deployment
# This script is referenced in render.yaml

set -o errexit  # Exit on any error
set -o nounset  # Exit on undefined variables
set -o pipefail # Exit on pipe failures

echo "🚀 Starting Render build process..."

echo "📦 Installing Ruby dependencies..."
bundle config --global frozen 1
bundle install --jobs=4 --retry=3

echo "📦 Installing Node.js dependencies..."
if [ -f "package.json" ]; then
  npm ci --production=false
else
  echo "⚠️  No package.json found, skipping Node.js dependencies"
fi

echo "🎨 Precompiling assets..."
bundle exec rails assets:precompile

echo "🗄️  Preparing database..."
# Create database if it doesn't exist (safe for existing databases)
bundle exec rails db:create DISABLE_DATABASE_ENVIRONMENT_CHECK=1 || true

echo "🔄 Running database migrations..."
bundle exec rails db:migrate

echo "🌱 Loading seed data..."
bundle exec rails db:seed

echo "🧹 Cleaning up build artifacts..."
rm -rf node_modules/.cache
rm -rf tmp/cache

echo "✅ Build completed successfully!"