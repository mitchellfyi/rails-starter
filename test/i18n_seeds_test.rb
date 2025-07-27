require 'test_helper'

class I18nSeedsTest < ActiveSupport::TestCase
  def setup
    # Clean slate
    FeatureFlag.destroy_all
    SystemPrompt.destroy_all
    Workspace.destroy_all
  end

  test "should detect multilingual mode correctly" do
    # Mock multiple locales
    original_locales = I18n.available_locales
    I18n.available_locales = [:en, :es]
    
    assert SeedI18nHelper.multilingual_enabled?
    assert_equal [:en, :es], SeedI18nHelper.available_locales
    
    # Restore
    I18n.available_locales = original_locales
  end

  test "should detect single locale mode correctly" do 
    # Mock single locale
    original_locales = I18n.available_locales
    I18n.available_locales = [:en]
    
    assert_not SeedI18nHelper.multilingual_enabled?
    assert_equal [:en], SeedI18nHelper.available_locales
    
    # Restore
    I18n.available_locales = original_locales
  end

  test "should return translation when available" do
    # Mock translation
    I18n.backend.store_translations(:en, { seeds: { test: "English" } })
    I18n.backend.store_translations(:es, { seeds: { test: "Español" } })
    
    result_en = SeedI18nHelper.seed_translation('seeds.test', locale: :en, fallback: 'Fallback')
    result_es = SeedI18nHelper.seed_translation('seeds.test', locale: :es, fallback: 'Fallback')
    
    assert_equal "English", result_en
    assert_equal "Español", result_es
  end

  test "should use fallback when translation missing" do
    result = SeedI18nHelper.seed_translation('seeds.nonexistent', locale: :en, fallback: 'Fallback')
    assert_equal "Fallback", result
  end

  test "should use fallback in single locale mode" do
    # Mock single locale
    original_locales = I18n.available_locales
    I18n.available_locales = [:en]
    
    result = SeedI18nHelper.seed_translation('seeds.test', locale: :en, fallback: 'Fallback')
    assert_equal "Fallback", result
    
    # Restore
    I18n.available_locales = original_locales
  end
end