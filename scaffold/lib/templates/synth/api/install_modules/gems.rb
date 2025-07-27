# frozen_string_literal: true

# API module gem dependencies installer

say_status :api_gems, "Installing API module gems"

# JSON:API and documentation gems
gem 'jsonapi-rails', '~> 0.4'
gem 'jsonapi-serializer', '~> 2.2'
gem 'rswag', '~> 2.13'
gem 'rswag-api', '~> 2.13'
gem 'rswag-ui', '~> 2.13'
gem 'rswag-specs', '~> 2.13'

say_status :api_gems, "API module gems added to Gemfile"