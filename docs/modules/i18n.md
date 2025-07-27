# I18n Module

Provides comprehensive internationalization support for your Rails SaaS application with locale detection middleware, RTL support, settings integration, and localized formatting.

## Features

- **Locale Detection Middleware:** Automatically detects user locale from Accept-Language headers, URL parameters, and user account preferences
- **RTL Support:** Full support for right-to-left languages with appropriate CSS classes and layout adjustments
- **Formatting:** Localized currency, number, and date/time formatting across the UI and JSON responses
- **Translations:** Organized translation keys in YAML files with English and Spanish translations
- **User Preferences:** Store user locale preferences in the database with settings page integration
- **Translation Helper:** Easy-to-use locale switcher component for navigation
- **Fallback Logic:** Intelligent fallback to default locale when translations are missing

## Installation

Install this module via:

```sh
bin/railsplan add i18n
```

This will:
- Add locale detection middleware class
- Create user locale preference migration
- Add I18n configuration to your Rails app
- Install translation files (English + Spanish)
- Add RTL CSS classes and helper methods
- Generate settings page integration components
- Generate comprehensive test files for locale functionality

## Usage

### Automatic Locale Detection

The locale is automatically detected via middleware in this order:
1. URL parameter (`?locale=es`)
2. User account preference (if logged in)
3. Accept-Language header
4. Default application locale

### Settings Page Integration

Include the language settings component in your settings page:

```erb
<%= render 'shared/language_settings' %>
```

This provides a dropdown for users to change their locale preference.

### Navigation Integration

Add a locale switcher to your navigation:

```erb
<%= render 'shared/locale_switcher' %>
```

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
2. Add locale to `config/initializers/i18n.rb`:
   ```ruby
   config.i18n.available_locales = [:en, :es, :your_locale]
   ```
3. Add RTL support if needed:
   ```ruby
   # Modify the RTL locales in config/initializers/i18n.rb if needed
   I18N_RTL_LOCALES = %i[ar he fa ur].freeze
   ```
4. Update locale name in helpers:
   ```ruby
   # In LocaleHelpers module
   when :your_locale then 'Your Language Name'
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
  settings:
    title: "Settings"
    language: "Language"
  common:
    save: "Save"
    cancel: "Cancel"
    delete: "Delete"
```

## Configuration

After installation, follow the integration steps:

1. **Add middleware** to `config/application.rb`:
   ```ruby
   config.middleware.use LocaleDetectionMiddleware
   ```

2. **Include controller concern** in `ApplicationController`:
   ```ruby
   include ApplicationController::LocaleManagement
   ```

3. **Update application layout** with RTL support:
   ```erb
   <html dir="<%= rtl_locale? ? 'rtl' : 'ltr' %>" lang="<%= I18n.locale %>">
   <body class="<%= rtl_aware_classes %>">
   ```

4. **Include CSS** for RTL support:
   ```erb
   <%= stylesheet_link_tag 'i18n', 'data-turbo-track': 'reload' %>
   ```

## Testing

The module includes comprehensive tests for:
- Locale detection from headers and user preferences
- Middleware functionality
- RTL CSS class generation
- Currency and date formatting
- Translation fallbacks
- User locale preference persistence
- Settings page integration

Run tests with:
```sh
bin/railsplan test i18n
```