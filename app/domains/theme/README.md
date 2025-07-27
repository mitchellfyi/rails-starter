# Theme and Brand Customization

A comprehensive theming framework for customizing colors, fonts, logos, and branding elements in your Rails SaaS application. Provides built-in light and dark mode support with easy CSS custom property overrides.

## Features

- **CSS Custom Properties**: Easy color, font, and spacing customization
- **Light/Dark Mode**: Built-in theme switching with system preference detection
- **Brand Assets**: Logo and icon management system
- **Typography**: Custom font loading and typographic scales
- **Component Themes**: Consistent styling across all UI components
- **Override System**: Simple CSS file for brand-specific customizations

## Installation

The theme module is automatically installed with the base template. To reinstall or upgrade:

```bash
bin/synth add theme
```

## Usage

### Basic Theme Customization

Create or edit `app/assets/stylesheets/theme.css` to override default theme variables:

```css
:root {
  /* Brand Colors */
  --brand-primary: #3b82f6;
  --brand-secondary: #64748b;
  --brand-accent: #f59e0b;
  
  /* Custom Fonts */
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'JetBrains Mono', 'Monaco', monospace;
}
```

### Dark Mode Customization

```css
[data-theme="dark"] {
  --brand-primary: #60a5fa;
  --brand-secondary: #94a3b8;
  --text-primary: #f8fafc;
  --bg-primary: #0f172a;
}
```

### Logo and Brand Assets

Place your brand assets in `app/assets/images/brand/`:

- `logo.svg` - Main logo
- `logo-dark.svg` - Dark mode logo variant  
- `icon.svg` - App icon/favicon
- `wordmark.svg` - Text-only logo variant

### Theme Configuration

Configure theme settings in `config/initializers/theme.rb`:

```ruby
Rails.application.configure do
  config.theme = ActiveSupport::OrderedOptions.new
  
  config.theme.default_mode = :system # :light, :dark, or :system
  config.theme.allow_user_preference = true
  config.theme.brand_name = "Your App"
  config.theme.custom_css_enabled = true
end
```

## Components

### Theme Switcher

Add theme switching to your layout:

```erb
<%= render 'shared/theme_switcher' %>
```

### Brand Logo

Display responsive brand logos:

```erb
<%= render 'shared/brand_logo', variant: :default, class: 'h-8' %>
```

## Advanced Customization

### Custom Color Palettes

Define complete color systems:

```css
:root {
  /* Primary Palette */
  --color-primary-50: #eff6ff;
  --color-primary-100: #dbeafe;
  --color-primary-500: #3b82f6;
  --color-primary-900: #1e3a8a;
  
  /* Semantic Colors */
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
}
```

### Typography Scales

```css
:root {
  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --text-xl: 1.25rem;
  --text-2xl: 1.5rem;
  
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;
}
```

## Files Added

- `app/assets/stylesheets/theme.css` - Theme override file
- `app/assets/stylesheets/_theme_variables.css` - Core theme variables
- `app/views/shared/_theme_switcher.html.erb` - Theme toggle component
- `app/views/shared/_brand_logo.html.erb` - Brand logo component
- `config/initializers/theme.rb` - Theme configuration
- `app/assets/images/brand/` - Brand asset directory

## Browser Support

- CSS Custom Properties (IE 11+ with polyfill)
- CSS Grid and Flexbox
- `prefers-color-scheme` media query
- Local storage for theme persistence