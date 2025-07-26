# I18n Module

Provides comprehensive internationalization support for your Rails SaaS application with locale detection, RTL support, and localized formatting.

## Features

- **Locale Detection:** Automatically detects user locale from Accept-Language headers and user account preferences
- **RTL Support:** Full support for right-to-left languages with appropriate CSS classes and layout adjustments
- **Formatting:** Localized currency, number, and date/time formatting across the UI and JSON responses
- **Translations:** Organized translation keys in YAML files with default English and sample Arabic translations
- **User Preferences:** Store user locale preferences in the database
- **Fallback Logic:** Intelligent fallback to default locale when translations are missing

## Installation

Install this module via:

```sh
bin/synth add i18n
```

This will:
- Add locale detection middleware
- Create user locale preference migration
- Add I18n configuration to your Rails app
- Install translation files (English + Arabic sample)
- Add RTL CSS classes and helper methods
- Generate test files for locale functionality

## Usage

### Setting User Locale

The locale is automatically detected and set from:
1. User account preference (if logged in)
2. URL parameter (`?locale=en`)
3. Accept-Language header
4. Default application locale

### RTL Support

Views automatically get RTL classes when using RTL locales:

```erb
<div class="<%= rtl_class('text-left', 'text-right') %>">
  Content that adapts to text direction
</div>

<%= content_tag :div, class: "container #{rtl_aware_classes}" do %>
  RTL-aware container
<% end %>
```

### Formatting

Use I18n helpers for consistent formatting:

```erb
<!-- Currency -->
<%= localize_currency(100.50) %>

<!-- Numbers -->
<%= localize_number(1234.56) %>

<!-- Dates -->
<%= localize_date(Date.current) %>
<%= localize_datetime(Time.current) %>
```

### Adding New Languages

1. Create translation file: `config/locales/[locale].yml`
2. Add locale to `config/application.rb`:
   ```ruby
   config.i18n.available_locales = [:en, :ar, :your_locale]
   ```
3. Add RTL support if needed:
   ```ruby
   # Modify the RTL locales in config/initializers/i18n.rb if needed
   I18N_RTL_LOCALES = %i[ar he fa ur].freeze
   ```

## Translation Organization

Translations are organized by module:

```yaml
en:
  auth:
    sign_in: "Sign In"
    sign_up: "Sign Up"
  billing:
    subscription: "Subscription"
    invoices: "Invoices"
  ai:
    prompts: "Prompts"
    outputs: "Outputs"
  common:
    save: "Save"
    cancel: "Cancel"
    delete: "Delete"
```

## Testing

The module includes comprehensive tests for:
- Locale detection from headers and user preferences
- RTL CSS class generation
- Currency and date formatting
- Translation fallbacks
- User locale preference persistence

Run tests with:
```sh
bin/synth test i18n
```