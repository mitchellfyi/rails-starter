# frozen_string_literal: true

# Synth AI module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the AI module.
# It is intentionally minimal; extend it to install generators, migrations, and configuration as needed.

say_status :synth_ai, "Installing AI module"

# Add AI specific gems to the application's Gemfile
add_gem 'ruby-openai'
add_gem 'pgvector'

# Run bundle install and set up AI configuration after gems are installed
after_bundle do
  # Create an initializer for AI configuration
  initializer 'ai.rb', <<~'RUBY'
    # AI module configuration
    # Set your default model and any other AI related settings here
    Rails.application.config.ai = ActiveSupport::OrderedOptions.new
    Rails.application.config.ai.default_model = 'gpt-4'
  RUBY

  # TODO: generate models, migrations, and other scaffolding for prompt templates and LLM outputs
  say_status :synth_ai, "AI module installed. Please run migrations and configure your API keys."
end
