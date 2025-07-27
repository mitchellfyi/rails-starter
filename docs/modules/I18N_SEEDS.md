# I18n/Locale-Driven Seed Content

This feature enhances the Rails SaaS Starter Template with comprehensive internationalization support for seed data, enabling multilingual MVPs from day one.

## Features

- **Automatic Locale Detection**: Seeds automatically detect if multiple locales are configured
- **Fallback Support**: When I18n is not fully configured, falls back to English content seamlessly
- **Translation-Aware Seeds**: All seed content can be localized including:
  - Feature flag descriptions
  - System prompt names, descriptions, and content
  - Workspace names and descriptions
  - Audit log messages
- **Backward Compatibility**: Existing single-locale applications continue to work without changes

## How It Works

### 1. I18n Helper

The `SeedI18nHelper` module provides:
- Detection of multilingual vs single-locale mode
- Translation loading with fallbacks
- Status reporting for seed operations

### 2. Locale Files

Translation files in `config/locales/`:
- `seeds.en.yml` - English translations
- `seeds.es.yml` - Spanish translations
- Additional languages can be added following the same pattern

### 3. Enhanced Seed Files

Existing seed files (`db/seeds/admin.rb`, `db/seeds/system_prompts.rb`) are enhanced to:
- Use translations when available
- Fall back to hardcoded English when not
- Provide clear status information during seeding

## Usage

### Basic Setup

1. **Configure Available Locales** (in `config/initializers/i18n.rb`):
```ruby
Rails.application.configure do
  config.i18n.available_locales = [:en, :es]  # Add your locales
  config.i18n.default_locale = :en
end
```

2. **Add Translation Files** (see `config/locales/seeds.*.yml` for examples)

3. **Run Seeds**:
```bash
rails db:seed
```

### Advanced Usage

**Seed Different Locales**:
```ruby
I18n.with_locale(:es) do
  load Rails.root.join('db/seeds/admin.rb')
end
```

**Check Status**:
```ruby
SeedI18nHelper.multilingual_enabled?     # => true/false
SeedI18nHelper.available_locales         # => [:en, :es]
```

## Configuration Options

### Single Locale Mode (Default Rails)
```ruby
config.i18n.available_locales = [:en]
```
- Seeds use fallback content (hardcoded English)
- Status: "📝 I18n detected but only single locale (en) - using fallback content"

### Multilingual Mode 
```ruby
config.i18n.available_locales = [:en, :es, :fr]
```
- Seeds use translation files
- Status: "🌍 I18n enabled with locales: en, es, fr"

## Translation File Structure

```yaml
en:
  seeds:
    feature_flags:
      ai_chat:
        description: "Enable AI chat functionality"
    system_prompts:
      generic_assistant:
        name: "Generic Assistant"
        description: "A helpful, harmless, and honest AI assistant"
        prompt_text: "You are a helpful AI assistant..."
    workspaces:
      demo_workspace:
        name: "Demo Workspace"
        description: "Sample workspace for demonstration"
```

## Adding New Locales

1. **Create translation file**: `config/locales/seeds.{locale}.yml`
2. **Add locale to configuration**: Update `config.i18n.available_locales`
3. **Run seeds**: `rails db:seed` or locale-specific seeding

## Example Output

### Multilingual Mode
```
🌱 Seeding Admin data...
🌍 I18n enabled with locales: en, es
✅ Feature flag 'ai_chat' ready (enabled)
```

### Single Locale Mode  
```
🌱 Seeding Admin data...
📝 I18n detected but only single locale (en) - using fallback content
✅ Feature flag 'ai_chat' ready (enabled)
```

## Benefits

- **Multilingual MVPs**: Start with localized content from day one
- **Zero Breaking Changes**: Existing applications continue working unchanged
- **Developer Friendly**: Clear status messages and easy configuration
- **Scalable**: Easy to add new languages and content areas
- **Production Ready**: Robust fallback handling and error prevention

## Files Added/Modified

### New Files
- `lib/seed_i18n_helper.rb` - Core I18n functionality for seeds
- `config/locales/seeds.en.yml` - English translations
- `config/locales/seeds.es.yml` - Spanish translations  
- `config/initializers/i18n.rb` - I18n configuration
- `db/seeds.rb` - Master seed file loader

### Modified Files
- `db/seeds/admin.rb` - Now I18n-aware
- `db/seeds/system_prompts.rb` - Now I18n-aware
- `app/models/system_prompt.rb` - Fixed for Rails 7.1 compatibility

This enhancement enables building truly international SaaS applications with localized seed content from the start, while maintaining full backward compatibility.