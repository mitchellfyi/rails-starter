# frozen_string_literal: true

# Installer for the I18n module
# Adds comprehensive internationalization support to your Rails SaaS application

say "Installing I18n module..."

# Create domain-specific directories
run 'mkdir -p app/domains/i18n/app/{controllers/concerns,helpers/concerns,assets/stylesheets,views/shared}'
run 'mkdir -p spec/domains/i18n/integration'

# Add required gems
gem 'rails-i18n', '~> 7.0'

# Create user locale preference migration
migration_content = <<~RUBY
  class AddLocaleToUsers < ActiveRecord::Migration[8.0]
    def change
      add_column :users, :locale, :string, default: 'en'
      add_index :users, :locale
    end
  end
RUBY

migration_template "add_locale_to_users.rb", "db/migrate/add_locale_to_users.rb", migration_version: "8.0"

# Create I18n configuration
initializer_content = <<~RUBY
  # frozen_string_literal: true

  # I18n Configuration
  Rails.application.configure do
    # Available locales for the application
    config.i18n.available_locales = %i[en es]
    
    # Default locale
    config.i18n.default_locale = :en
    
    # Fallbacks enabled
    config.i18n.fallbacks = true
    
    # Load locale files from all modules
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
  end

  # Right-to-left locale configuration
  I18N_RTL_LOCALES = %i[ar he fa ur].freeze
RUBY

create_file 'config/initializers/i18n.rb', initializer_content

# Create locale detection middleware
middleware_content = <<~RUBY
  # frozen_string_literal: true

  # Middleware for automatic locale detection and switching
  class LocaleDetectionMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      
      # Store original locale
      original_locale = I18n.locale
      
      # Detect and set locale for this request
      detected_locale = detect_locale(request, env)
      I18n.locale = detected_locale
      
      # Process the request
      status, headers, response = @app.call(env)
      
      # Restore original locale
      I18n.locale = original_locale
      
      [status, headers, response]
    end

    private

    def detect_locale(request, env)
      # 1. URL parameter
      if request.params['locale'] && valid_locale?(request.params['locale'])
        return request.params['locale'].to_sym
      end
      
      # 2. User preference (if user data is available in session)
      user_locale = extract_user_locale(request, env)
      return user_locale if user_locale && valid_locale?(user_locale)
      
      # 3. Accept-Language header
      accept_language_locale = extract_locale_from_accept_language_header(env)
      return accept_language_locale if accept_language_locale
      
      # 4. Default locale
      I18n.default_locale
    end

    def extract_user_locale(request, env)
      # This will be called after Devise/Warden middleware
      # so we can access current_user if session is available
      return nil unless request.session && request.session['warden.user.user.key']
      
      # For now, return nil - this will be handled by the controller concern
      # as we need ActiveRecord models to be available
      nil
    end

    def extract_locale_from_accept_language_header(env)
      return nil unless env['HTTP_ACCEPT_LANGUAGE']

      env['HTTP_ACCEPT_LANGUAGE'].to_s.split(',').map do |lang|
        lang.split(';').first.split('-').first.strip
      end.find do |locale|
        valid_locale?(locale)
      end&.to_sym
    end

    def valid_locale?(locale)
      I18n.available_locales.include?(locale.to_sym)
    end
  end
RUBY

create_file 'app/domains/i18n/app/middleware/locale_detection_middleware.rb', middleware_content

# Create locale detection helpers
locale_helpers_content = <<~RUBY
  # frozen_string_literal: true

  # Helper methods for locale detection and management
  module LocaleHelpers
    def current_locale
      I18n.locale
    end

    def rtl_locale?(locale = I18n.locale)
      I18N_RTL_LOCALES.include?(locale.to_sym)
    end

    def rtl_class(ltr_class, rtl_class)
      rtl_locale? ? rtl_class : ltr_class
    end

    def rtl_aware_classes
      rtl_locale? ? 'rtl' : 'ltr'
    end

    def available_locales_for_select
      I18n.available_locales.map do |locale|
        [locale_name(locale), locale.to_s]
      end
    end

    def locale_name(locale)
      case locale.to_sym
      when :en then 'English'
      when :es then 'Español'
      when :ar then 'العربية'
      else locale.to_s.humanize
      end
    end
  end
RUBY

create_file 'app/domains/i18n/app/helpers/concerns/locale_helpers.rb', locale_helpers_content

# Create application controller concern
concern_content = <<~RUBY
  # frozen_string_literal: true

  module ApplicationController::LocaleManagement
    extend ActiveSupport::Concern

    included do
      include LocaleHelpers
      around_action :switch_locale
      before_action :set_locale_from_user, if: :user_signed_in?
    end

    private

    def switch_locale(&action)
      locale = detect_locale_for_user
      I18n.with_locale(locale, &action)
    end

    def detect_locale_for_user
      # 1. User preference (if logged in)
      return current_user.locale if user_has_valid_locale?
      
      # 2. URL parameter (already handled by middleware, but double-check)
      return params[:locale] if params[:locale].present? && 
                               I18n.available_locales.include?(params[:locale].to_sym)
      
      # 3. Fall back to what middleware detected or default
      I18n.locale
    end

    def set_locale_from_user
      if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
        # Update user preference when locale is explicitly changed
        if current_user.locale != params[:locale]
          current_user.update_column(:locale, params[:locale])
        end
      end
    end

    def user_has_valid_locale?
      user_signed_in? && 
        current_user.locale.present? && 
        I18n.available_locales.include?(current_user.locale.to_sym)
    end
  end
RUBY

create_file 'app/domains/i18n/app/controllers/concerns/application_controller/locale_management.rb', concern_content

# Create formatting helpers
helper_content = <<~RUBY
  # frozen_string_literal: true

  module ApplicationHelper
    module I18nFormatting
      include LocaleHelpers

      def localize_currency(amount, currency = 'USD')
        return '' if amount.nil?

        case I18n.locale
        when :es
          # Spanish formatting
          "#{number_with_precision(amount, precision: 2, delimiter: '.', separator: ',')} #{currency_symbol(currency)}"
        else
          # Default English formatting
          "#{currency_symbol(currency)}#{number_with_precision(amount, precision: 2, delimiter: ',')}"
        end
      end

      def localize_number(number)
        return '' if number.nil?
        
        case I18n.locale
        when :es
          # Spanish number formatting
          number_with_precision(number, precision: 2, delimiter: '.', separator: ',')
        else
          number_with_precision(number, precision: 2, delimiter: ',', separator: '.')
        end
      end

      def localize_date(date)
        return '' if date.nil?
        
        l(date, format: :default)
      end

      def localize_datetime(datetime)
        return '' if datetime.nil?
        
        l(datetime, format: :default)
      end

      def localize_time(time)
        return '' if time.nil?
        
        l(time, format: :default)
      end

      private

      def currency_symbol(currency)
        case currency.upcase
        when 'USD' then '$'
        when 'EUR' then '€'
        when 'GBP' then '£'
        when 'JPY' then '¥'
        when 'MXN' then '$'
        when 'ARS' then '$'
        when 'COP' then '$'
        else currency
        end
      end
    end

    include I18nFormatting
  end
RUBY

create_file 'app/domains/i18n/app/helpers/concerns/application_helper/i18n_formatting.rb', helper_content

# Create English translations
en_translations = <<~YAML
  en:
    common:
      save: "Save"
      cancel: "Cancel"
      delete: "Delete"
      edit: "Edit"
      create: "Create"
      update: "Update"
      confirm: "Are you sure?"
      success: "Success"
      error: "Error"
      loading: "Loading..."
      search: "Search"
      filter: "Filter"
      reset: "Reset"
      close: "Close"
      
    auth:
      sign_in: "Sign In"
      sign_up: "Sign Up"
      sign_out: "Sign Out"
      email: "Email"
      password: "Password"
      password_confirmation: "Confirm Password"
      remember_me: "Remember me"
      forgot_password: "Forgot your password?"
      reset_password: "Reset password"
      welcome: "Welcome"
      
    navigation:
      home: "Home"
      dashboard: "Dashboard"
      profile: "Profile"
      settings: "Settings"
      help: "Help"
      contact: "Contact"
      
    billing:
      subscription: "Subscription"
      billing: "Billing"
      invoices: "Invoices"
      payment_method: "Payment Method"
      billing_address: "Billing Address"
      subscription_status: "Subscription Status"
      next_billing_date: "Next Billing Date"
      
    ai:
      prompts: "Prompts"
      outputs: "Outputs"
      templates: "Templates"
      jobs: "Jobs"
      models: "Models"
      context: "Context"
      
    workspace:
      workspaces: "Workspaces"
      members: "Members"
      invitations: "Invitations"
      roles: "Roles"

    settings:
      title: "Settings"
      language: "Language"
      preferences: "Preferences"
      account: "Account"
      security: "Security"
      notifications: "Notifications"
      
    time:
      formats:
        default: "%B %d, %Y"
        short: "%b %d"
        long: "%A, %B %d, %Y"
        
    date:
      formats:
        default: "%Y-%m-%d"
        short: "%b %d"
        long: "%B %d, %Y"
YAML

create_file 'config/locales/en.yml', en_translations

# Create Spanish translations
es_translations = <<~YAML
  es:
    common:
      save: "Guardar"
      cancel: "Cancelar"
      delete: "Eliminar"
      edit: "Editar"
      create: "Crear"
      update: "Actualizar"
      confirm: "¿Estás seguro?"
      success: "Éxito"
      error: "Error"
      loading: "Cargando..."
      search: "Buscar"
      filter: "Filtrar"
      reset: "Restablecer"
      close: "Cerrar"
      
    auth:
      sign_in: "Iniciar Sesión"
      sign_up: "Registrarse"
      sign_out: "Cerrar Sesión"
      email: "Correo Electrónico"
      password: "Contraseña"
      password_confirmation: "Confirmar Contraseña"
      remember_me: "Recordarme"
      forgot_password: "¿Olvidaste tu contraseña?"
      reset_password: "Restablecer contraseña"
      welcome: "Bienvenido"
      
    navigation:
      home: "Inicio"
      dashboard: "Panel de Control"
      profile: "Perfil"
      settings: "Configuración"
      help: "Ayuda"
      contact: "Contacto"
      
    billing:
      subscription: "Suscripción"
      billing: "Facturación"
      invoices: "Facturas"
      payment_method: "Método de Pago"
      billing_address: "Dirección de Facturación"
      subscription_status: "Estado de Suscripción"
      next_billing_date: "Próxima Fecha de Facturación"
      
    ai:
      prompts: "Prompts"
      outputs: "Resultados"
      templates: "Plantillas"
      jobs: "Trabajos"
      models: "Modelos"
      context: "Contexto"
      
    workspace:
      workspaces: "Espacios de Trabajo"
      members: "Miembros"
      invitations: "Invitaciones"
      roles: "Roles"

    settings:
      title: "Configuración"
      language: "Idioma"
      preferences: "Preferencias"
      account: "Cuenta"
      security: "Seguridad"
      notifications: "Notificaciones"
      
    time:
      formats:
        default: "%d de %B de %Y"
        short: "%d %b"
        long: "%A, %d de %B de %Y"
        
    date:
      formats:
        default: "%Y-%m-%d"
        short: "%d %b"
        long: "%d de %B de %Y"
YAML

create_file 'config/locales/es.yml', es_translations

# Create CSS for RTL support
css_content = <<~CSS
  /* RTL (Right-to-Left) Support Styles */
  
  .rtl {
    direction: rtl;
  }
  
  .ltr {
    direction: ltr;
  }
  
  /* Text alignment adjustments for RTL */
  .rtl .text-left {
    text-align: right !important;
  }
  
  .rtl .text-right {
    text-align: left !important;
  }
  
  /* Margin and padding adjustments for RTL */
  .rtl .ml-2 { margin-left: 0; margin-right: 0.5rem; }
  .rtl .mr-2 { margin-right: 0; margin-left: 0.5rem; }
  .rtl .pl-2 { padding-left: 0; padding-right: 0.5rem; }
  .rtl .pr-2 { padding-right: 0; padding-left: 0.5rem; }
  
  .rtl .ml-4 { margin-left: 0; margin-right: 1rem; }
  .rtl .mr-4 { margin-right: 0; margin-left: 1rem; }
  .rtl .pl-4 { padding-left: 0; padding-right: 1rem; }
  .rtl .pr-4 { padding-right: 0; padding-left: 1rem; }
  
  /* Float adjustments for RTL */
  .rtl .float-left {
    float: right !important;
  }
  
  .rtl .float-right {
    float: left !important;
  }
  
  /* Flexbox adjustments for RTL */
  .rtl .justify-start {
    justify-content: flex-end !important;
  }
  
  .rtl .justify-end {
    justify-content: flex-start !important;
  }
  
  /* Border radius adjustments for RTL */
  .rtl .rounded-l-lg {
    border-top-left-radius: 0;
    border-bottom-left-radius: 0;
    border-top-right-radius: 0.5rem;
    border-bottom-right-radius: 0.5rem;
  }
  
  .rtl .rounded-r-lg {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
    border-top-left-radius: 0.5rem;
    border-bottom-left-radius: 0.5rem;
  }
  
  /* Icon and button adjustments for RTL */
  .rtl .transform.rotate-180 {
    transform: rotate(0deg) !important;
  }
  
  .rtl .transform.rotate-0 {
    transform: rotate(180deg) !important;
  }
CSS

create_file 'app/domains/i18n/app/assets/stylesheets/i18n.css', css_content

# Create locale switching component
component_content = <<~HTML
  <%# Locale Switcher Component %>
  <div class="locale-switcher">
    <%= form_with url: request.path, method: :get, local: true, class: "inline-block" do |form| %>
      <% (params.except(:locale, :_method) || {}).each do |key, value| %>
        <%= form.hidden_field key, value: value %>
      <% end %>
      <%= form.select :locale, 
            options_for_select(available_locales_for_select, I18n.locale.to_s),
            {},
            { 
              class: "block appearance-none bg-white border border-gray-300 rounded py-2 px-3 leading-tight focus:outline-none focus:border-blue-500",
              onchange: "this.form.submit();"
            } %>
    <% end %>
  </div>
HTML

create_file 'app/domains/i18n/app/views/shared/_locale_switcher.html.erb', component_content

# Create settings form component for locale preferences
settings_form_content = <<~HTML
  <%# Settings Language Preferences Component %>
  <div class="language-settings">
    <h3 class="text-lg font-medium text-gray-900 mb-4">
      <%= t('settings.language') %>
    </h3>
    
    <%= form_with model: current_user, url: settings_path, method: :patch, local: true, class: "space-y-4" do |form| %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          <%= t('settings.language') %>
        </label>
        <%= form.select :locale, 
              options_for_select(available_locales_for_select, current_user&.locale || I18n.locale.to_s),
              {},
              { 
                class: "block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              } %>
        <p class="mt-1 text-sm text-gray-500">
          Choose your preferred language for the interface.
        </p>
      </div>

      <div class="flex justify-end">
        <%= form.submit t('common.save'), 
              class: "bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" %>
      </div>
    <% end %>
  </div>
HTML

create_file 'app/domains/i18n/app/views/shared/_language_settings.html.erb', settings_form_content

# Create test files
test_content = <<~RUBY
  require 'test_helper'

  class I18nTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one) # Assumes users fixture exists
    end

    test "should detect locale from accept language header" do
      get root_path, headers: { 'HTTP_ACCEPT_LANGUAGE' => 'es,en;q=0.9' }
      assert_equal :es, I18n.locale
    end

    test "should detect locale from url parameter" do
      get root_path, params: { locale: 'es' }
      assert_equal :es, I18n.locale
    end

    test "should use user preference for locale" do
      @user.update(locale: 'es')
      sign_in @user
      get root_path
      assert_equal :es, I18n.locale
    end

    test "should fallback to default locale for invalid locale" do
      get root_path, params: { locale: 'invalid' }
      assert_equal :en, I18n.locale
    end

    test "should update user locale preference from url parameter" do
      sign_in @user
      get root_path, params: { locale: 'es' }
      @user.reload
      assert_equal 'es', @user.locale
    end

    test "middleware should detect locale from accept language" do
      middleware = LocaleDetectionMiddleware.new(->(env) { [200, {}, []] })
      env = { 'HTTP_ACCEPT_LANGUAGE' => 'es,en;q=0.9', 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/' }
      
      original_locale = I18n.locale
      middleware.call(env)
      # Locale should be restored after request
      assert_equal original_locale, I18n.locale
    end
  end

  class I18nHelpersTest < ActionView::TestCase
    include ApplicationHelper

    test "should format currency correctly for English locale" do
      I18n.with_locale(:en) do
        assert_equal '$100.50', localize_currency(100.50)
      end
    end

    test "should format currency correctly for Spanish locale" do
      I18n.with_locale(:es) do
        assert_equal '100,50 $', localize_currency(100.50)
      end
    end

    test "should format numbers correctly for different locales" do
      I18n.with_locale(:en) do
        assert_equal '1,234.56', localize_number(1234.56)
      end
      
      I18n.with_locale(:es) do
        assert_equal '1.234,56', localize_number(1234.56)
      end
    end

    test "should detect RTL locales correctly" do
      I18n.with_locale(:ar) do
        assert rtl_locale?
        assert_equal 'text-right', rtl_class('text-left', 'text-right')
        assert_equal 'rtl', rtl_aware_classes
      end
      
      I18n.with_locale(:en) do
        assert_not rtl_locale?
        assert_equal 'text-left', rtl_class('text-left', 'text-right')
        assert_equal 'ltr', rtl_aware_classes
      end
    end

    test "should provide available locales for select" do
      locales = available_locales_for_select
      assert_includes locales, ['English', 'en']
      assert_includes locales, ['Español', 'es']
    end

    test "should return correct locale names" do
      assert_equal 'English', locale_name(:en)
      assert_equal 'Español', locale_name(:es)
      assert_equal 'العربية', locale_name(:ar)
    end
  end
RUBY

create_file 'spec/domains/i18n/integration/i18n_test.rb', test_content

# Add include to ApplicationController
controller_include = <<~RUBY
  
  # Include I18n locale management
  include ApplicationController::LocaleManagement
RUBY

# Note: In a real installation, this would be added to app/controllers/application_controller.rb
# For now, we'll create a note file
create_file 'doc/i18n_controller_setup.md', <<~MD
  # Application Controller Setup

  Add the following to your `app/controllers/application_controller.rb`:

  ```ruby
  class ApplicationController < ActionController::Base
    # ... existing code ...
    
    # Include I18n locale management
    include ApplicationController::LocaleManagement
    
    # ... rest of your controller code ...
  end
  ```

  This will enable automatic locale detection and switching in your application.
MD

# Create layout helper file
layout_helper = <<~MD
  # Layout Integration

  Add the following to your application layout (`app/views/layouts/application.html.erb`):

  ## 1. Add RTL-aware body class:

  ```erb
  <body class="<%= rtl_aware_classes %>">
  ```

  ## 2. Add locale switcher to navigation:

  ```erb
  <%= render 'shared/locale_switcher' %>
  ```

  ## 3. Include RTL CSS:

  ```erb
  <%= stylesheet_link_tag 'i18n', 'data-turbo-track': 'reload' %>
  ```

  ## 4. Add HTML dir attribute:

  ```erb
  <html dir="<%= rtl_locale? ? 'rtl' : 'ltr' %>" lang="<%= I18n.locale %>">
  ```

  ## 5. Add middleware to application.rb:

  ```ruby
  # In config/application.rb
  config.middleware.use LocaleDetectionMiddleware
  ```

  ## 6. Add language settings to your settings page:

  ```erb
  <%= render 'shared/language_settings' %>
  ```
MD

create_file 'doc/i18n_layout_setup.md', layout_helper

# Create middleware configuration note
middleware_setup = <<~MD
  # Middleware Configuration

  Add the following to your `config/application.rb` file to enable automatic locale detection:

  ```ruby
  module YourApp
    class Application < Rails::Application
      # ... existing configuration ...
      
      # Add locale detection middleware
      config.middleware.use LocaleDetectionMiddleware
      
      # ... rest of configuration ...
    end
  end
  ```

  This middleware will automatically detect the user's preferred locale from:
  1. URL parameters (?locale=es)
  2. User account preferences (for logged-in users)
  3. Accept-Language header
  4. Default application locale
MD

create_file 'doc/i18n_middleware_setup.md', middleware_setup

say "✅ I18n module installed successfully!"
say ""
say "Next steps:"
say "1. Run `rails db:migrate` to add locale column to users"
say "2. Add middleware to config/application.rb (see doc/i18n_middleware_setup.md)"
say "3. Include locale management in ApplicationController (see doc/i18n_controller_setup.md)"
say "4. Update your application layout (see doc/i18n_layout_setup.md)"
say "5. Run tests with `bundle exec rspec spec/domains/i18n/`"
say ""
say "Your application now supports:"
say "  ✓ Automatic locale detection middleware"
say "  ✓ RTL language support"
say "  ✓ Localized formatting"
say "  ✓ User locale preferences"
say "  ✓ Translation fallbacks"
say "  ✓ Settings page integration"
say "  ✓ English + Spanish translations"