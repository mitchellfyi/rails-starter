# TestFeature Module

Brief description of what this module provides for the Rails SaaS starter template.

## Features

- Feature 1: Description
- Feature 2: Description  
- Feature 3: Description

## Installation

```bash
bin/synth add test_feature
```

## Usage

Describe how to use this module after installation.

### Configuration

Configure the module in `config/initializers/test_feature.rb`:

```ruby
Rails.application.configure do
  config.test_feature = ActiveSupport::OrderedOptions.new
  
  # Add your configuration options here
  config.test_feature.enabled = true
end
```

### Basic Usage

```ruby
# Example usage code
```

## Components Added

- **Controllers**: `app/domains/test_feature/app/controllers/`
- **Models**: `app/domains/test_feature/app/models/`
- **Views**: `app/domains/test_feature/app/views/`
- **Services**: `app/domains/test_feature/app/services/`
- **Tests**: `spec/domains/test_feature/` or `test/domains/test_feature/`

## Configuration

- **Initializer**: `config/initializers/test_feature.rb`
- **Routes**: Routes are added to `config/routes.rb`

## Database Changes

This module includes the following database changes:

- Migration: `db/migrate/*_create_test_feature_tables.rb`

## Dependencies

This module requires:

- Ruby 3.0+
- Rails 7.0+
- PostgreSQL with required extensions

## Testing

Run tests for this module:

```bash
bin/synth test test_feature
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
