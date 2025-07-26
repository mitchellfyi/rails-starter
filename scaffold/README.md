# Rails SaaS Starter Template Scaffolding

This directory contains the core scaffolding files for the Rails SaaS Starter Template, including the main template script and modular features.

## Files Overview

- `template.rb` - Main Rails template script for bootstrapping new applications
- `lib/synth/cli.rb` - Command-line interface for managing modules
- `lib/templates/synth/` - Directory containing installable modules
- `bin/synth` - CLI entry point

## Using the Template

### Creating a New Application

To create a new Rails application using this template:

```bash
rails new myapp --dev -m path/to/scaffold/template.rb
```

Or from a URL (when hosted):

```bash
rails new myapp --dev -m https://example.com/template.rb
```

### What the Template Does

The template script will:

1. **Check Requirements** - Verify Ruby >= 3.1.0 and Rails >= 7.0.0
2. **Install Core Gems** - Add PostgreSQL, pgvector, Redis, Sidekiq, Devise, etc.
3. **Setup Environment** - Create `.env.example` with sample configuration
4. **Install Frontend** - Configure Hotwire (Turbo + Stimulus) and TailwindCSS
5. **Setup Authentication** - Generate Devise User model
6. **Configure Background Jobs** - Set Sidekiq as the Active Job adapter
7. **Create Models** - Generate Workspace and Membership models for multi-tenancy
8. **Install CLI** - Create `bin/synth` command-line tool
9. **Initialize Git** - Create initial commit

## Module System

The template includes a modular architecture where features are organized as separate modules under `lib/templates/synth/`.

### Available Modules

- **ai** - Comprehensive AI integration with prompt templates, LLM jobs, and context providers

### Installing Modules

After creating your application, use the `bin/synth` CLI to manage modules:

```bash
# List available modules
bin/synth list

# Install the AI module
bin/synth add ai

# Run tests for a specific module
bin/synth test ai

# Check your setup
bin/synth doctor
```

## Creating New Modules

To create a new module:

1. Create a directory: `lib/templates/synth/my_module/`
2. Add an `install.rb` file with installation logic
3. Add a `README.md` file with documentation
4. Optional: Add tests, seeds, and other supporting files

### Module Structure

```
lib/templates/synth/my_module/
├── install.rb          # Installation script (required)
├── README.md           # Documentation (recommended)
├── seeds/              # Seed data files
│   └── my_module_seeds.rb
├── migrations/         # Database migrations
│   └── create_my_models.rb
└── spec/              # Tests specific to this module
    └── my_module_spec.rb
```

### Example install.rb

```ruby
# frozen_string_literal: true

say_status :my_module, "Installing My Module..."

# Add gems
gem 'my_gem', '~> 1.0'

after_bundle do
  # Generate models
  generate :model, 'MyModel', 'name:string'
  
  # Create initializer
  create_file 'config/initializers/my_module.rb', <<~CONFIG
    Rails.application.config.my_module = ActiveSupport::OrderedOptions.new
    Rails.application.config.my_module.enabled = true
  CONFIG
  
  # Run migrations
  rails_command 'db:migrate'
  
  say_status :my_module, "My Module installed successfully!"
end
```

## CLI Extension

The `bin/synth` CLI can be extended by modifying `lib/synth/cli.rb`. It's built on Thor, so you can add new commands easily:

```ruby
desc 'my_command', 'Description of my command'
def my_command
  puts 'Executing my command...'
end
```

## Testing

The template includes a basic test script at `test/template_test.rb` that verifies:

- Template file exists
- Template has valid Ruby syntax

To run the tests:

```bash
ruby test/template_test.rb
```

For more comprehensive testing, create a new Rails app using the template and verify it boots correctly.

## Environment Configuration

The template creates a `.env.example` file with common configuration options:

- Database URLs
- Redis configuration
- API keys for third-party services
- Devise secrets

Copy this to `.env` and configure for your specific environment.

## Customization

The template is designed to be customized for your specific needs:

1. **Modify gem versions** in `template.rb`
2. **Add new generators** in the `after_bundle` block
3. **Create custom modules** for your specific features
4. **Extend the CLI** with project-specific commands

## Best Practices

1. **Keep modules focused** - Each module should handle a single concern
2. **Document everything** - Include clear README files for each module
3. **Test thoroughly** - Verify modules work independently and together
4. **Version carefully** - Pin gem versions for reproducible builds
5. **Follow Rails conventions** - Use standard Rails patterns and idioms