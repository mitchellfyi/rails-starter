# frozen_string_literal: true

# Admin module gem dependencies installer
# This modular installer handles gem installation for the admin module

say_status :admin_gems, "Installing admin module gems"

# Core admin gems
gem 'flipper', '~> 1.3'
gem 'flipper-ui', '~> 1.3' 
gem 'flipper-active_record', '~> 1.3'
gem 'paper_trail', '~> 15.0'

unless File.read('Gemfile').include?('pundit')
  gem 'pundit', '~> 2.1'  # Use consistent version with main template
end

gem 'request_store'
gem 'kaminari'

say_status :admin_gems, "Admin module gems added to Gemfile"