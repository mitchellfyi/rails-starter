# TestWithHyphens Module

Brief description of what this module provides for the Rails SaaS starter template.

## Features

- Feature 1: Description
- Feature 2: Description  
- Feature 3: Description

## Installation

```bash
bin/railsplan add test-with-hyphens
```

## Usage

Describe how to use this module after installation.

### Configuration

Configure the module in `config/initializers/test-with-hyphens.rb`:

```ruby
Rails.application.configure do
  config.test-with-hyphens = ActiveSupport::OrderedOptions.new
  
  # Add your configuration options here
  config.test-with-hyphens.enabled = true
end
```

### Basic Usage

```ruby
# Example usage code
```

## Components Added

- **Controllers**: `app/domains/test-with-hyphens/app/controllers/`
- **Models**: `app/domains/test-with-hyphens/app/models/`
- **Views**: `app/domains/test-with-hyphens/app/views/`
- **Services**: `app/domains/test-with-hyphens/app/services/`
- **Tests**: `spec/domains/test-with-hyphens/` or `test/domains/test-with-hyphens/`

## Configuration

- **Initializer**: `config/initializers/test-with-hyphens.rb`
- **Routes**: Routes are added to `config/routes.rb`

## Database Changes

This module includes the following database changes:

- Migration: `db/migrate/*_create_test-with-hyphens_tables.rb`

## Dependencies

This module requires:

- Ruby 3.0+
- Rails 7.0+
- PostgreSQL with required extensions

## Testing

Run tests for this module:

```bash
bin/railsplan test test-with-hyphens
```

## Customization

Describe how users can customize this module for their needs.

## API

If this module provides API endpoints, document them here.

## Troubleshooting

Common issues and solutions:

### Issue 1
Problem description and solution.

### Issue 2
Problem description and solution.

## Support

For issues related to this module, please check:

- [Rails SaaS Starter Template Documentation](../../../README.md)
- [Module test files](test/) for usage examples
