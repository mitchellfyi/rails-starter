# frozen_string_literal: true

# Add gems to the Gemfile
gem 'pg', '~> 1.5'
gem 'pgvector', '~> 0.5'
gem 'redis', '~> 5.4'
gem 'sidekiq', '~> 8.0'

# Authentication and authorization
gem 'devise', '~> 4.9'
gem 'omniauth', '~> 2.1'
gem 'omniauth-google-oauth2', '~> 1.2'
gem 'omniauth-github', '~> 2.0'
gem 'omniauth-slack', '~> 2.5'
gem 'omniauth-rails-csrf-protection', '~> 1.0'
gem 'stripe', '~> 15.3'
gem 'pundit', '~> 2.1'
gem 'friendly_id', '~> 5.5'
gem 'rolify', '~> 6.0'

# Frontend
gem 'turbo-rails', '~> 1.5'
gem 'stimulus-rails', '~> 1.2'
gem 'tailwindcss-rails', '~> 4.3'

# API and JSON handling
gem 'jsonapi-serializer', '~> 3.2'
gem 'rswag', '~> 2.14'

# Utilities
gem 'image_processing', '~> 1.13'
gem 'bootsnap', '~> 1.18', require: false

gem_group :development, :test do
  gem 'dotenv-rails', '~> 3.1'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.3'
  gem 'rspec-rails', '~> 8.0'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'shoulda-matchers', '~> 6.5'
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.27'
  gem 'webmock', '~> 3.24'
end

gem_group :development do
  gem 'web-console', '~> 4.2'
  gem 'listen', '~> 3.8'
  gem 'spring', '~> 4.1'
  gem 'bullet', '~> 7.0'
  gem 'brakeman', '~> 6.0'
  gem 'rubocop', '~> 1.60'
end
