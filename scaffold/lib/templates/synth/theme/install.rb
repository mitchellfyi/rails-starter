# frozen_string_literal: true

# Synth Theme module installer for the Rails SaaS starter template.
# This module sets up a comprehensive theming framework with CSS custom properties,
# light/dark mode support, and brand customization capabilities.

say_status :theme, "Installing theme and brand customization framework"

after_bundle do
  # Create theme-related directories
  run 'mkdir -p app/assets/stylesheets'
  run 'mkdir -p app/assets/images/brand'
  run 'mkdir -p app/views/shared'
  
  # Create core theme variables CSS file
  create_file 'app/assets/stylesheets/_theme_variables.css', <<~CSS
    /* Theme Variables - Core Design System */
    /* This file contains the base theme variables. Override them in theme.css */
    
    :root {
      /* Color System */
      --color-primary-50: #eff6ff;
      --color-primary-100: #dbeafe;
      --color-primary-200: #bfdbfe;
      --color-primary-300: #93c5fd;
      --color-primary-400: #60a5fa;
      --color-primary-500: #3b82f6;
      --color-primary-600: #2563eb;
      --color-primary-700: #1d4ed8;
      --color-primary-800: #1e40af;
      --color-primary-900: #1e3a8a;
      
      --color-gray-50: #f8fafc;
      --color-gray-100: #f1f5f9;
      --color-gray-200: #e2e8f0;
      --color-gray-300: #cbd5e1;
      --color-gray-400: #94a3b8;
      --color-gray-500: #64748b;
      --color-gray-600: #475569;
      --color-gray-700: #334155;
      --color-gray-800: #1e293b;
      --color-gray-900: #0f172a;
      
      /* Semantic Colors */
      --color-success: #10b981;
      --color-warning: #f59e0b;
      --color-error: #ef4444;
      --color-info: #3b82f6;
      
      /* Brand Colors (Override these in theme.css) */
      --brand-primary: var(--color-primary-600);
      --brand-secondary: var(--color-gray-600);
      --brand-accent: var(--color-primary-500);
      
      /* Text Colors */
      --text-primary: var(--color-gray-900);
      --text-secondary: var(--color-gray-600);
      --text-tertiary: var(--color-gray-500);
      --text-inverse: var(--color-gray-50);
      
      /* Background Colors */
      --bg-primary: #ffffff;
      --bg-secondary: var(--color-gray-50);
      --bg-tertiary: var(--color-gray-100);
      --bg-inverse: var(--color-gray-900);
      
      /* Border Colors */
      --border-primary: var(--color-gray-200);
      --border-secondary: var(--color-gray-300);
      --border-focus: var(--brand-primary);
      
      /* Typography */
      --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
      --font-serif: 'Georgia', 'Times New Roman', 'Times', serif;
      --font-mono: 'SFMono-Regular', 'Monaco', 'Consolas', 'Liberation Mono', 'Courier New', monospace;
      
      /* Font Sizes */
      --text-xs: 0.75rem;
      --text-sm: 0.875rem;
      --text-base: 1rem;
      --text-lg: 1.125rem;
      --text-xl: 1.25rem;
      --text-2xl: 1.5rem;
      --text-3xl: 1.875rem;
      --text-4xl: 2.25rem;
      
      /* Font Weights */
      --font-weight-light: 300;
      --font-weight-normal: 400;
      --font-weight-medium: 500;
      --font-weight-semibold: 600;
      --font-weight-bold: 700;
      
      /* Spacing Scale */
      --space-1: 0.25rem;
      --space-2: 0.5rem;
      --space-3: 0.75rem;
      --space-4: 1rem;
      --space-5: 1.25rem;
      --space-6: 1.5rem;
      --space-8: 2rem;
      --space-10: 2.5rem;
      --space-12: 3rem;
      --space-16: 4rem;
      --space-20: 5rem;
      
      /* Border Radius */
      --radius-sm: 0.125rem;
      --radius-md: 0.375rem;
      --radius-lg: 0.5rem;
      --radius-xl: 0.75rem;
      --radius-2xl: 1rem;
      --radius-full: 9999px;
      
      /* Shadows */
      --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
      --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
      --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
      --shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1);
      
      /* Transitions */
      --transition-fast: 150ms ease;
      --transition-base: 200ms ease;
      --transition-slow: 300ms ease;
    }
    
    /* Dark Theme */
    [data-theme="dark"] {
      /* Override colors for dark mode */
      --text-primary: var(--color-gray-50);
      --text-secondary: var(--color-gray-300);
      --text-tertiary: var(--color-gray-400);
      --text-inverse: var(--color-gray-900);
      
      --bg-primary: var(--color-gray-900);
      --bg-secondary: var(--color-gray-800);
      --bg-tertiary: var(--color-gray-700);
      --bg-inverse: var(--color-gray-50);
      
      --border-primary: var(--color-gray-700);
      --border-secondary: var(--color-gray-600);
      
      /* Adjust brand colors for dark mode */
      --brand-primary: var(--color-primary-400);
      --brand-secondary: var(--color-gray-300);
    }
    
    /* System theme detection */
    @media (prefers-color-scheme: dark) {
      [data-theme="system"] {
        --text-primary: var(--color-gray-50);
        --text-secondary: var(--color-gray-300);
        --text-tertiary: var(--color-gray-400);
        --text-inverse: var(--color-gray-900);
        
        --bg-primary: var(--color-gray-900);
        --bg-secondary: var(--color-gray-800);
        --bg-tertiary: var(--color-gray-700);
        --bg-inverse: var(--color-gray-50);
        
        --border-primary: var(--color-gray-700);
        --border-secondary: var(--color-gray-600);
        
        --brand-primary: var(--color-primary-400);
        --brand-secondary: var(--color-gray-300);
      }
    }
    
    /* Base styles using theme variables */
    body {
      font-family: var(--font-sans);
      color: var(--text-primary);
      background-color: var(--bg-primary);
      transition: background-color var(--transition-base), color var(--transition-base);
    }
  CSS
  
  # Create theme override file (user customizable)
  create_file 'app/assets/stylesheets/theme.css', <<~CSS
    /* Theme Customization Override File */
    /* 
     * This file is for your brand-specific theme customizations.
     * Override any of the CSS custom properties from _theme_variables.css here.
     * This file will not be overwritten when the theme module is updated.
     */
    
    :root {
      /* Example: Custom brand colors */
      /* --brand-primary: #your-brand-color; */
      /* --brand-secondary: #your-secondary-color; */
      /* --brand-accent: #your-accent-color; */
      
      /* Example: Custom fonts */
      /* --font-sans: 'Your Custom Font', -apple-system, BlinkMacSystemFont, sans-serif; */
      
      /* Example: Custom spacing or sizing */
      /* --space-custom: 2.5rem; */
    }
    
    /* Dark mode customizations */
    [data-theme="dark"] {
      /* Example: Adjust brand colors for dark mode */
      /* --brand-primary: #lighter-version-of-brand-color; */
    }
    
    /* Custom component styles using theme variables */
    .btn-primary {
      background-color: var(--brand-primary);
      color: var(--text-inverse);
      border: 1px solid var(--brand-primary);
      border-radius: var(--radius-md);
      padding: var(--space-2) var(--space-4);
      font-weight: var(--font-weight-medium);
      transition: all var(--transition-fast);
    }
    
    .btn-primary:hover {
      opacity: 0.9;
      transform: translateY(-1px);
      box-shadow: var(--shadow-md);
    }
    
    .card {
      background-color: var(--bg-primary);
      border: 1px solid var(--border-primary);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-sm);
      padding: var(--space-6);
    }
    
    .input-field {
      background-color: var(--bg-primary);
      border: 1px solid var(--border-primary);
      border-radius: var(--radius-md);
      padding: var(--space-2) var(--space-3);
      color: var(--text-primary);
      transition: border-color var(--transition-fast);
    }
    
    .input-field:focus {
      border-color: var(--border-focus);
      outline: none;
      box-shadow: 0 0 0 3px rgb(59 130 246 / 0.1);
    }
  CSS
  
  # Create theme switcher component
  create_file 'app/views/shared/_theme_switcher.html.erb', <<~ERB
    <div class="theme-switcher" data-controller="theme-switcher">
      <label for="theme-select" class="sr-only">Choose theme</label>
      <select 
        id="theme-select" 
        data-theme-switcher-target="select"
        data-action="change->theme-switcher#changeTheme"
        class="input-field"
      >
        <option value="system">System</option>
        <option value="light">Light</option>
        <option value="dark">Dark</option>
      </select>
    </div>
  ERB
  
  # Create brand logo component
  create_file 'app/views/shared/_brand_logo.html.erb', <<~ERB
    <%
      variant = local_assigns[:variant] || :default
      css_class = local_assigns[:class] || 'h-8'
      alt_text = local_assigns[:alt] || Rails.application.config.theme&.brand_name || 'Logo'
      
      # Determine which logo to use based on variant and theme
      logo_path = case variant
                  when :icon
                    'brand/icon.svg'
                  when :wordmark
                    'brand/wordmark.svg'
                  else
                    'brand/logo.svg'
                  end
      
      dark_logo_path = case variant
                       when :icon
                         'brand/icon-dark.svg'
                       when :wordmark
                         'brand/wordmark-dark.svg'
                       else
                         'brand/logo-dark.svg'
                       end
    %>
    
    <div class="brand-logo">
      <!-- Light theme logo -->
      <% if asset_exists?(logo_path) %>
        <%= image_tag logo_path, 
            alt: alt_text,
            class: css_class + " dark:hidden",
            loading: 'lazy' %>
      <% end %>
      
      <!-- Dark theme logo (if available) -->
      <% if asset_exists?(dark_logo_path) %>
        <%= image_tag dark_logo_path, 
            alt: alt_text,
            class: css_class + " hidden dark:block",
            loading: 'lazy' %>
      <% end %>
      
      <!-- Fallback text if no logo images exist -->
      <% unless asset_exists?(logo_path) %>
        <span class="font-bold text-lg text-brand-primary">
          <%= alt_text %>
        </span>
      <% end %>
    </div>
  ERB
  
  # Create theme switcher Stimulus controller
  run 'mkdir -p app/javascript/controllers'
  create_file 'app/javascript/controllers/theme_switcher_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"
    
    // Connects to data-controller="theme-switcher"
    export default class extends Controller {
      static targets = ["select"]
      
      connect() {
        // Set initial theme from localStorage or system preference
        const savedTheme = localStorage.getItem('theme') || 'system'
        this.selectTarget.value = savedTheme
        this.applyTheme(savedTheme)
      }
      
      changeTheme(event) {
        const theme = event.target.value
        localStorage.setItem('theme', theme)
        this.applyTheme(theme)
      }
      
      applyTheme(theme) {
        const html = document.documentElement
        
        // Remove existing theme attributes
        html.removeAttribute('data-theme')
        
        if (theme === 'system') {
          // Let CSS handle system preference
          html.setAttribute('data-theme', 'system')
        } else {
          // Apply specific theme
          html.setAttribute('data-theme', theme)
        }
        
        // Dispatch custom event for other components
        window.dispatchEvent(new CustomEvent('themeChanged', { 
          detail: { theme } 
        }))
      }
    }
  JS
  
  # Create example brand assets directory with placeholder files
  create_file 'app/assets/images/brand/.gitkeep', ''
  
  # Create a simple SVG logo placeholder
  create_file 'app/assets/images/brand/logo.svg', <<~SVG
    <svg width="120" height="40" viewBox="0 0 120 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="120" height="40" rx="8" fill="#3B82F6"/>
      <text x="60" y="25" text-anchor="middle" fill="white" font-family="sans-serif" font-size="14" font-weight="600">
        Your Logo
      </text>
    </svg>
  SVG
  
  # Create dark variant of the logo
  create_file 'app/assets/images/brand/logo-dark.svg', <<~SVG
    <svg width="120" height="40" viewBox="0 0 120 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="120" height="40" rx="8" fill="#60A5FA"/>
      <text x="60" y="25" text-anchor="middle" fill="white" font-family="sans-serif" font-size="14" font-weight="600">
        Your Logo
      </text>
    </svg>
  SVG
  
  # Create icon version
  create_file 'app/assets/images/brand/icon.svg', <<~SVG
    <svg width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="40" height="40" rx="8" fill="#3B82F6"/>
      <circle cx="20" cy="20" r="12" fill="white"/>
      <circle cx="20" cy="20" r="6" fill="#3B82F6"/>
    </svg>
  SVG
  
  # Create theme configuration initializer
  create_file 'config/initializers/theme.rb', <<~RUBY
    # frozen_string_literal: true
    
    # Theme Configuration
    # Configure theme settings for your Rails SaaS application
    
    Rails.application.configure do
      config.theme = ActiveSupport::OrderedOptions.new
      
      # Default theme mode (:light, :dark, or :system)
      config.theme.default_mode = :system
      
      # Allow users to override theme preference
      config.theme.allow_user_preference = true
      
      # Brand configuration
      config.theme.brand_name = Rails.application.class.module_parent_name
      config.theme.brand_description = "A modern SaaS application"
      
      # Enable custom CSS overrides
      config.theme.custom_css_enabled = true
      
      # Theme switching animation duration (in milliseconds)
      config.theme.transition_duration = 200
      
      # Asset configuration
      config.theme.logo_formats = %w[svg png jpg]
      config.theme.brand_assets_path = 'brand'
    end
    
    # Helper method to check if asset exists
    module ThemeHelper
      def asset_exists?(path)
        if Rails.application.assets
          Rails.application.assets.find_asset(path).present?
        else
          Rails.application.assets_manifest.assets[path].present?
        end
      rescue
        false
      end
    end
    
    # Include helper in ActionView
    ActionView::Base.include ThemeHelper if defined?(ActionView::Base)
  RUBY
  
  # Update application CSS to import theme files
  application_css_path = 'app/assets/stylesheets/application.css'
  tailwind_css_path = 'app/assets/stylesheets/application.tailwind.css'
  
  # Determine which CSS file to modify
  css_file_to_modify = if File.exist?(tailwind_css_path)
    tailwind_css_path
  elsif File.exist?(application_css_path)
    application_css_path
  else
    # Create a basic application CSS file
    create_file application_css_path, <<~CSS
      /*
       * This is a manifest file that'll be compiled into application.css, which will include all the files
       * listed below.
       *
       *= require_tree .
       *= require_self
       */
    CSS
    application_css_path
  end
  
  # Add theme imports to CSS file
  if File.exist?(css_file_to_modify)
    prepend_to_file css_file_to_modify, <<~CSS
      /* Theme Framework Imports */
      @import "_theme_variables";
      @import "theme";
      
    CSS
  end
  
  say_status :theme, "✅ Theme framework installed successfully!"
  say_status :theme, "📝 Edit app/assets/stylesheets/theme.css to customize your brand"
  say_status :theme, "🎨 Add your logo files to app/assets/images/brand/"
  say_status :theme, "⚙️  Configure theme settings in config/initializers/theme.rb"
end