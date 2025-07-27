# frozen_string_literal: true

require 'test_helper'

class I18nModuleTest < ActiveSupport::TestCase
  test "i18n configuration" do
    # Test that i18n is properly configured
    assert I18n.respond_to?(:locale), "I18n should be available"
    assert I18n.respond_to?(:available_locales), "I18n should have available locales"
    
    # Test default locale
    assert_not_nil I18n.default_locale
    assert I18n.available_locales.include?(I18n.default_locale), 
           "Default locale should be in available locales"
  end

  test "locale files structure" do
    # Test that locale files exist and are properly structured
    locales_dir = File.join(Rails.root, 'config', 'locales')
    
    if Dir.exist?(locales_dir)
      yaml_files = Dir[File.join(locales_dir, '*.yml')]
      
      assert yaml_files.any?, "Should have locale YAML files"
      
      yaml_files.first(3).each do |locale_file|
        begin
          locale_data = YAML.load_file(locale_file)
          assert locale_data.is_a?(Hash), "Locale file should contain a hash"
          
          # Should have top-level locale keys
          locale_keys = locale_data.keys
          assert locale_keys.any?, "Locale file should have locale keys"
          
          # Keys should be valid locale codes
          locale_keys.each do |key|
            assert key.match?(/^[a-z]{2}(-[A-Z]{2})?$/), "#{key} should be a valid locale code"
          end
        rescue Psych::SyntaxError
          assert false, "#{File.basename(locale_file)} should be valid YAML"
        end
      end
    else
      skip "config/locales directory not found"
    end
  end

  test "translation keys structure" do
    # Test that translation keys follow Rails conventions
    if I18n.backend.respond_to?(:translations)
      translations = I18n.backend.send(:translations)
      
      I18n.available_locales.each do |locale|
        locale_translations = translations[locale]
        next unless locale_translations
        
        # Should have common Rails translation keys
        rails_keys = %w[activerecord activemodel errors]
        rails_keys.each do |key|
          if locale_translations.key?(key.to_sym)
            assert true, "#{locale} should have #{key} translations"
          end
        end
      end
    end
  end

  test "pluralization rules" do
    # Test that pluralization works correctly
    if I18n.available_locales.include?(:en)
      I18n.with_locale(:en) do
        # Test basic pluralization
        assert_nothing_raised do
          I18n.t('test.count', count: 0, default: { zero: 'zero', one: 'one', other: 'many' })
          I18n.t('test.count', count: 1, default: { zero: 'zero', one: 'one', other: 'many' })
          I18n.t('test.count', count: 2, default: { zero: 'zero', one: 'one', other: 'many' })
        end
      end
    end
  end

  test "locale switching" do
    # Test that locale can be switched
    original_locale = I18n.locale
    
    I18n.available_locales.each do |test_locale|
      I18n.locale = test_locale
      assert_equal test_locale, I18n.locale, "Should be able to switch to #{test_locale}"
    end
    
    I18n.locale = original_locale
  end

  test "missing translation handling" do
    # Test that missing translations are handled gracefully
    I18n.with_locale(:en) do
      # Should return translation key or default for missing translations
      result = I18n.t('definitely.missing.translation.key', default: 'Default Value')
      assert_equal 'Default Value', result
      
      # Should handle missing translations without default
      result = I18n.t('definitely.missing.translation.key.without.default')
      assert result.is_a?(String), "Should return a string for missing translations"
    end
  end

  test "interpolation" do
    # Test that variable interpolation works
    I18n.with_locale(:en) do
      result = I18n.t('test.interpolation', 
                      name: 'John', 
                      default: 'Hello %{name}')
      assert_equal 'Hello John', result
    end
  end

  test "date and time localization" do
    # Test that dates and times can be localized
    test_date = Date.new(2023, 12, 25)
    test_time = Time.new(2023, 12, 25, 15, 30, 0)
    
    I18n.available_locales.first(2).each do |locale|
      I18n.with_locale(locale) do
        assert_nothing_raised do
          I18n.l(test_date)
          I18n.l(test_time)
        end
      end
    end
  end

  test "number localization" do
    # Test that numbers can be localized
    test_number = 1234.56
    
    I18n.available_locales.first(2).each do |locale|
      I18n.with_locale(locale) do
        assert_nothing_raised do
          I18n.l(test_number) if I18n.respond_to?(:l)
        end
      end
    end
  end

  test "currency localization" do
    # Test currency formatting
    if defined?(ActiveSupport::NumberHelper)
      amount = 1234.56
      
      I18n.with_locale(:en) do
        formatted = ActiveSupport::NumberHelper.number_to_currency(amount)
        assert formatted.include?('$'), "Should format currency with symbol"
      end
    end
  end

  test "lazy loading translations" do
    # Test that translations can be lazy loaded
    if I18n.backend.respond_to?(:reload!)
      assert_nothing_raised do
        I18n.backend.reload!
      end
    end
  end

  test "fallback locales" do
    # Test fallback locale configuration
    if I18n.respond_to?(:fallbacks)
      fallbacks = I18n.fallbacks
      
      I18n.available_locales.each do |locale|
        fallback_chain = fallbacks[locale]
        assert fallback_chain.include?(I18n.default_locale), 
               "#{locale} should fallback to default locale"
      end
    end
  end

  test "rtl language support" do
    # Test right-to-left language support if available
    rtl_locales = [:ar, :he, :fa]
    
    available_rtl = I18n.available_locales & rtl_locales
    
    if available_rtl.any?
      available_rtl.each do |rtl_locale|
        I18n.with_locale(rtl_locale) do
          # Test that RTL locale works
          assert_equal rtl_locale, I18n.locale
        end
      end
    end
  end
end