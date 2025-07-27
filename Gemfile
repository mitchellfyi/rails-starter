source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

# Use Rails edge (main branch) by default, with Rails 8 as fallback
# To use Rails 8 stable instead, comment out the edge line and uncomment the stable line
gem 'rails', github: 'rails/rails', branch: 'main'
# gem 'rails', '~> 8.0.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails', '>= 3.4.0'

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 2.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.0'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Redis adapter to run Action Cable in production and caching
gem 'redis', '~> 5.0'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem 'kredis'

# Use Active Model has_secure_password [https://github.com/bcrypt-ruby/bcrypt-ruby]
gem 'bcrypt', '~> 3.1.7'

# Security gems for paranoid mode
gem 'secure_headers', '~> 6.5'
gem 'attr_encrypted', '~> 4.0'

# Notification system for enhanced UX
gem 'noticed', '~> 2.0'

# View components for better UI organization
gem 'view_component', '~> 3.0'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
# gem 'sassc-rails'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem 'image_processing', '~> 1.2'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri windows ]
  
  # Accessibility testing
  gem 'axe-core-rspec'
  
  # Testing for 2FA (when paranoid mode is enabled)
  gem 'rqrcode', '~> 2.2'
  gem 'rotp', '~> 6.3'
  
  # N+1 query detection for performance optimization
  # gem 'bullet'  # Temporarily disabled due to Rails edge compatibility
  
  # Code quality and style checking
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-performance', require: false
  
  # gem testing dependencies
  gem 'rspec', '~> 3.12'
  gem 'rake', '~> 13.0'
  gem 'rubocop-rspec', '~> 2.20'
  gem 'simplecov', '~> 0.22'
  gem 'webmock', '~> 3.18'
  gem 'vcr', '~> 6.1'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem 'rack-mini-profiler'

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem 'spring'
end

# RailsPlan gem development dependencies (for CLI development)
# These are also defined in railsplan.gemspec for the gem itself
group :development do
  # CLI framework and TTY gems for RailsPlan CLI
  gem 'thor', '~> 1.3'
  gem 'tty-prompt', '~> 0.23'
  gem 'pastel', '~> 0.8'
  gem 'tty-spinner', '~> 0.9'
  gem 'tty-command', '~> 0.10'
  gem 'tty-which', '~> 0.5'
  gem 'tty-file', '~> 0.8'
  gem 'tty-logger', '~> 0.6'
  gem 'tty-config', '~> 0.6'
  gem 'tty-table', '~> 0.12'
  gem 'tty-markdown', '~> 0.7'
  gem 'tty-progressbar', '~> 0.18'
  gem 'tty-screen', '~> 0.8'
  gem 'tty-cursor', '~> 0.5'
  gem 'tty-reader', '~> 0.9'
  gem 'tty-editor', '~> 0.6'
  gem 'tty-pager', '~> 0.14'
  gem 'tty-link', '~> 0.1'
  gem 'tty-font', '~> 0.5'
  gem 'tty-box', '~> 0.7'
  gem 'tty-tree', '~> 0.4'
  gem 'tty-color', '~> 0.5'
  gem 'tty-platform', '~> 0.3'
  gem 'tty-option', '~> 0.2'
end
gem "rspec-rails", "~> 8.0", groups: [:development, :test]
