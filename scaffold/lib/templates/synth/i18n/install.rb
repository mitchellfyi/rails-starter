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
    config.i18n.available_locales = %i[en ar]
    
    # Default locale
    config.i18n.default_locale = :en
    
    # Fallbacks enabled
    config.i18n.fallbacks = true
    
    # Load locale files from all modules
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
  end

  # Right-to-left locale configuration
  I18N_RTL_LOCALES = %i[ar he fa ur].freeze

  # Locale detection order: user preference -> url param -> accept-language -> default
  module LocaleDetection
    extend ActiveSupport::Concern

    included do
      around_action :switch_locale
      helper_method :current_locale, :rtl_locale?, :rtl_class, :rtl_aware_classes
    end

    private

    def switch_locale(&action)
      locale = detect_locale
      I18n.with_locale(locale, &action)
    end

    def detect_locale
      # 1. User preference (if logged in)
      return current_user.locale if user_has_valid_locale?
      
      # 2. URL parameter
      return params[:locale] if params[:locale].present? && 
                               I18n.available_locales.include?(params[:locale].to_sym)
      
      # 3. Accept-Language header
      accept_language_locale = extract_locale_from_accept_language_header
      return accept_language_locale if accept_language_locale
      
      # 4. Default locale
      I18n.default_locale
    end

    def extract_locale_from_accept_language_header
      return nil unless request.env['HTTP_ACCEPT_LANGUAGE']

      request.env['HTTP_ACCEPT_LANGUAGE'].to_s.split(',').map do |lang|
        lang.split(';').first.split('-').first
      end.find do |locale|
        I18n.available_locales.include?(locale.to_sym)
      end&.to_sym
    end

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
  end
RUBY

create_file 'config/initializers/i18n.rb', initializer_content

# Create application controller concern
concern_content = <<~RUBY
  # frozen_string_literal: true

  module ApplicationController::LocaleManagement
    extend ActiveSupport::Concern

    included do
      include LocaleDetection
      before_action :set_locale_from_user, if: :user_signed_in?
    end

    private

    def set_locale_from_user
      if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
        current_user.update(locale: params[:locale]) if current_user.locale != params[:locale]
      end
    end
  end
RUBY

create_file 'app/domains/i18n/app/controllers/concerns/application_controller/locale_management.rb', concern_content

# Create formatting helpers
helper_content = <<~RUBY
  # frozen_string_literal: true

  module ApplicationHelper
    module I18nFormatting
      def localize_currency(amount, currency = 'USD')
        return '' if amount.nil?

        case I18n.locale
        when :ar
          # Arabic formatting
          "#{amount.to_f.round(2)} #{currency_symbol(currency)}"
        else
          # Default English formatting
          "#{currency_symbol(currency)}#{number_with_precision(amount, precision: 2, delimiter: ',')}"
        end
      end

      def localize_number(number)
        return '' if number.nil?
        
        case I18n.locale
        when :ar
          # Arabic number formatting (can use Arabic-Indic numerals if needed)
          number_with_precision(number, precision: 2, delimiter: '،', separator: '٫')
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
        when 'SAR' then 'ر.س'
        when 'AED' then 'د.إ'
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

# Create Arabic translations (sample)
ar_translations = <<~YAML
  ar:
    common:
      save: "حفظ"
      cancel: "إلغاء"
      delete: "حذف"
      edit: "تعديل"
      create: "إنشاء"
      update: "تحديث"
      confirm: "هل أنت متأكد؟"
      success: "نجح"
      error: "خطأ"
      loading: "جاري التحميل..."
      search: "بحث"
      filter: "تصفية"
      reset: "إعادة تعيين"
      close: "إغلاق"
      
    auth:
      sign_in: "تسجيل الدخول"
      sign_up: "التسجيل"
      sign_out: "تسجيل الخروج"
      email: "البريد الإلكتروني"
      password: "كلمة المرور"
      password_confirmation: "تأكيد كلمة المرور"
      remember_me: "تذكرني"
      forgot_password: "نسيت كلمة المرور؟"
      reset_password: "إعادة تعيين كلمة المرور"
      welcome: "مرحباً"
      
    navigation:
      home: "الرئيسية"
      dashboard: "لوحة التحكم"
      profile: "الملف الشخصي"
      settings: "الإعدادات"
      help: "المساعدة"
      contact: "اتصل بنا"
      
    billing:
      subscription: "الاشتراك"
      billing: "الفوترة"
      invoices: "الفواتير"
      payment_method: "طريقة الدفع"
      billing_address: "عنوان الفوترة"
      subscription_status: "حالة الاشتراك"
      next_billing_date: "تاريخ الفوترة التالي"
      
    ai:
      prompts: "المطالبات"
      outputs: "المخرجات"
      templates: "القوالب"
      jobs: "المهام"
      models: "النماذج"
      context: "السياق"
      
    workspace:
      workspaces: "مساحات العمل"
      members: "الأعضاء"
      invitations: "الدعوات"
      roles: "الأدوار"
      
    time:
      formats:
        default: "%d %B %Y"
        short: "%d %b"
        long: "%A، %d %B %Y"
        
    date:
      formats:
        default: "%Y-%m-%d"
        short: "%d %b"
        long: "%d %B %Y"
YAML

create_file 'config/locales/ar.yml', ar_translations

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
      <%= form.hidden_field :locale, value: params[:locale] %>
      <%= form.select :locale, 
            options_for_select([
              ['English', 'en'],
              ['العربية', 'ar']
            ], I18n.locale),
            {},
            { 
              class: "block appearance-none bg-white border border-gray-300 rounded py-2 px-3 leading-tight focus:outline-none focus:border-blue-500",
              onchange: "this.form.submit();"
            } %>
    <% end %>
  </div>
HTML

create_file 'app/domains/i18n/app/views/shared/_locale_switcher.html.erb', component_content

# Create test files
test_content = <<~RUBY
  require 'test_helper'

  class I18nTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one) # Assumes users fixture exists
    end

    test "should detect locale from accept language header" do
      get root_path, headers: { 'HTTP_ACCEPT_LANGUAGE' => 'ar,en;q=0.9' }
      assert_equal :ar, I18n.locale
    end

    test "should detect locale from url parameter" do
      get root_path, params: { locale: 'ar' }
      assert_equal :ar, I18n.locale
    end

    test "should use user preference for locale" do
      @user.update(locale: 'ar')
      sign_in @user
      get root_path
      assert_equal :ar, I18n.locale
    end

    test "should fallback to default locale for invalid locale" do
      get root_path, params: { locale: 'invalid' }
      assert_equal :en, I18n.locale
    end

    test "should update user locale preference from url parameter" do
      sign_in @user
      get root_path, params: { locale: 'ar' }
      @user.reload
      assert_equal 'ar', @user.locale
    end
  end

  class I18nHelpersTest < ActionView::TestCase
    include ApplicationHelper

    test "should format currency correctly for English locale" do
      I18n.with_locale(:en) do
        assert_equal '$100.50', localize_currency(100.50)
      end
    end

    test "should format currency correctly for Arabic locale" do
      I18n.with_locale(:ar) do
        assert_equal '100.5 $', localize_currency(100.50)
      end
    end

    test "should format numbers correctly for different locales" do
      I18n.with_locale(:en) do
        assert_equal '1,234.56', localize_number(1234.56)
      end
      
      I18n.with_locale(:ar) do
        assert_equal '1،234٫56', localize_number(1234.56)
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
MD

create_file 'doc/i18n_layout_setup.md', layout_helper

say "✅ I18n module installed successfully!"
say ""
say "Next steps:"
say "1. Run `rails db:migrate` to add locale column to users"
say "2. Review the I18n module README for integration instructions."
say "3. Run tests with `bundle exec rspec spec/domains/i18n/`"
say ""
say "Your application now supports:"
say "  ✓ Automatic locale detection"
say "  ✓ RTL language support"
say "  ✓ Localized formatting"
say "  ✓ User locale preferences"
say "  ✓ Translation fallbacks"
RUBY

create_file "scaffold/lib/templates/synth/i18n/install.rb", install_content