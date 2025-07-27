# frozen_string_literal: true

# API module gem dependencies installer

say_status :api_gems, "Installing API module gems"

# JSON:API and documentation gems (check if not already present)
gem 'jsonapi-rails', '~> 0.4'

unless File.read('Gemfile').include?('jsonapi-serializer')
  gem 'jsonapi-serializer', '~> 3.2'  # Use consistent version with main template
end

unless File.read('Gemfile').include?('rswag')
  gem 'rswag', '~> 2.14'  # Use consistent version with main template
end

gem 'rswag-api', '~> 2.14'
gem 'rswag-ui', '~> 2.14'
gem 'rswag-specs', '~> 2.14'

say_status :api_gems, "API module gems added to Gemfile"