# frozen_string_literal: true

# Synth Theme module installer for the Rails SaaS starter template.
# This module sets up a comprehensive theming framework with CSS custom properties,
# light/dark mode support, and brand customization capabilities.

say_status :theme, "Installing theme and brand customization framework"

after_bundle do
  # Helper methods for template operations
  def insert_into_file(path, content, options = {})
    if File.exist?(path)
      file_content = File.read(path)
      if options[:after]
        file_content.gsub!(options[:after], "#{options[:after]}#{content}")
      else
        file_content += content
      end
      File.write(path, file_content)
    end
  end
  
  def append_to_file(path, content)
    if File.exist?(path)
      File.open(path, 'a') { |f| f.write(content) }
    end
  end
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
    <div class="theme-switcher" 
         data-controller="theme-switcher"
         data-theme-switcher-sync-url-value="<%= theme_preference_path %>"
         data-theme-switcher-csrf-token-value="<%= form_authenticity_token %>">
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
  
  # Create theme preferences controller
  run 'mkdir -p app/controllers'
  create_file 'app/controllers/theme_preferences_controller.rb', <<~RUBY
    # frozen_string_literal: true
    
    # Controller for managing user theme preferences
    # Supports both session-based and database-based storage
    class ThemePreferencesController < ApplicationController
      VALID_THEMES = %w[light dark system].freeze
      
      # GET /theme_preference
      def show
        theme = current_theme_preference
        render json: { theme: theme }
      end
      
      # POST /theme_preference
      def update
        theme = params[:theme]
        
        unless VALID_THEMES.include?(theme)
          render json: { error: 'Invalid theme' }, status: :unprocessable_entity
          return
        end
        
        # Store in session
        session[:theme_preference] = theme
        
        # Store in database if user is authenticated and has theme preference support
        if user_signed_in? && current_user.respond_to?(:theme_preference=)
          current_user.update(theme_preference: theme)
        end
        
        render json: { theme: theme, status: 'saved' }
      end
      
      private
      
      def current_theme_preference
        # Priority: database > session > default
        if user_signed_in? && current_user.respond_to?(:theme_preference)
          current_user.theme_preference.presence || 
          session[:theme_preference] || 
          default_theme
        else
          session[:theme_preference] || default_theme
        end
      end
      
      def default_theme
        Rails.application.config.theme&.default_mode&.to_s || 'system'
      end
    end
  RUBY
  
  # Create theme switcher Stimulus controller with server sync
  run 'mkdir -p app/javascript/controllers'
  create_file 'app/javascript/controllers/theme_switcher_controller.js', <<~JS
    import { Controller } from "@hotwired/stimulus"
    
    // Connects to data-controller="theme-switcher"
    export default class extends Controller {
      static targets = ["select"]
      static values = { 
        syncUrl: String,
        csrfToken: String
      }
      
      connect() {
        // Load theme preference from server, fallback to localStorage
        this.loadThemePreference()
      }
      
      async loadThemePreference() {
        let theme = 'system'
        
        try {
          // Try to get theme from server first
          if (this.syncUrlValue) {
            const response = await fetch(this.syncUrlValue, {
              headers: {
                'Accept': 'application/json',
                'X-CSRF-Token': this.csrfTokenValue
              }
            })
            
            if (response.ok) {
              const data = await response.json()
              theme = data.theme || 'system'
            }
          }
        } catch (error) {
          console.log('Theme sync unavailable, using localStorage fallback')
        }
        
        // Fallback to localStorage if server sync failed
        if (!theme || theme === 'system') {
          theme = localStorage.getItem('theme') || 'system'
        }
        
        this.selectTarget.value = theme
        this.applyTheme(theme)
        
        // Sync localStorage with server preference
        localStorage.setItem('theme', theme)
      }
      
      async changeTheme(event) {
        const theme = event.target.value
        
        // Apply theme immediately for responsiveness
        this.applyTheme(theme)
        localStorage.setItem('theme', theme)
        
        // Sync with server
        await this.syncThemePreference(theme)
      }
      
      async syncThemePreference(theme) {
        if (!this.syncUrlValue) return
        
        try {
          const response = await fetch(this.syncUrlValue, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-CSRF-Token': this.csrfTokenValue
            },
            body: JSON.stringify({ theme: theme })
          })
          
          if (response.ok) {
            const data = await response.json()
            if (data.status === 'saved') {
              console.log('Theme preference saved to server')
            }
          }
        } catch (error) {
          console.log('Failed to sync theme preference to server:', error)
          // Theme still works via localStorage, so this is not critical
        }
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
  
  # Add theme configuration initializer
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
      
      # Server-side persistence settings
      config.theme.enable_server_sync = true
      config.theme.enable_database_persistence = true
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
  
  # Add routes for theme preferences
  routes_file = 'config/routes.rb'
  if File.exist?(routes_file)
    route_content = File.read(routes_file)
    unless route_content.include?('theme_preference')
      # Add theme preference routes
      routes_to_add = "\n  # Theme preference management\n  resource :theme_preference, only: [:show, :update]\n"
      
      if route_content.include?('Rails.application.routes.draw do')
        # Insert after the routes.draw line
        insert_into_file routes_file, routes_to_add, after: "Rails.application.routes.draw do"
      else
        append_to_file routes_file, routes_to_add
      end
    end
  else
    create_file routes_file, <<~RUBY
      Rails.application.routes.draw do
        # Theme preference management
        resource :theme_preference, only: [:show, :update]
      end
    RUBY
  end
  
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
  say_status :theme, "🔗 Theme preferences will be persisted in session and optionally in database"
  
  # Create optional database migration for user theme preferences
  migration_template = <<~MIGRATION
    class AddThemePreferenceToUsers < ActiveRecord::Migration[7.0]
      def change
        add_column :users, :theme_preference, :string, default: 'system'
        add_index :users, :theme_preference
      end
    end
  MIGRATION
  
  # Create migration file with timestamp
  timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  migration_file = "db/migrate/#{timestamp}_add_theme_preference_to_users.rb"
  create_file migration_file, migration_template
  
  say_status :theme, "📄 Optional migration created: #{migration_file}"
  say_status :theme, "   Run 'rails db:migrate' to add theme preference to users table"
  say_status :theme, "   (Skip if your app doesn't have a users table or you prefer session-only storage)"
end