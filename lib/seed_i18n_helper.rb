# frozen_string_literal: true

# I18n helper for seed files to support multilingual content
module SeedI18nHelper
  def self.multilingual_enabled?
    @multilingual_enabled ||= I18n.available_locales.size > 1
  end

  def self.available_locales
    @available_locales ||= I18n.available_locales
  end

  def self.seed_translation(key, locale: I18n.locale, fallback: nil)
    return fallback unless multilingual_enabled?
    
    begin
      I18n.t(key, locale: locale, raise: true)
    rescue I18n::MissingTranslationData
      fallback
    end
  end

  def self.seed_content_for_all_locales(base_key, content_key, fallback_content = {})
    return { I18n.locale => fallback_content } unless multilingual_enabled?
    
    result = {}
    
    available_locales.each do |locale|
      content = {}
      
      if fallback_content.is_a?(Hash)
        fallback_content.each do |field, default_value|
          field_key = "#{base_key}.#{content_key}.#{field}"
          content[field] = seed_translation(field_key, locale: locale, fallback: default_value)
        end
      else
        content = seed_translation("#{base_key}.#{content_key}", locale: locale, fallback: fallback_content)
      end
      
      result[locale] = content
    end
    
    result
  end

  def self.create_localized_records(model_class, records_config)
    return unless multilingual_enabled?
    
    records_config.each do |record_key, config|
      base_data = config[:base_data] || {}
      fallback_content = config[:fallback_content] || {}
      i18n_key = config[:i18n_key] || "seeds.#{model_class.table_name}.#{record_key}"
      identifier_field = config[:identifier_field] || :name
      
      available_locales.each do |locale|
        I18n.with_locale(locale) do
          # Build localized data
          localized_data = base_data.dup
          
          fallback_content.each do |field, default_value|
            field_key = "#{i18n_key}.#{field}"
            localized_data[field] = seed_translation(field_key, locale: locale, fallback: default_value)
          end
          
          # Create unique identifier for this locale
          identifier_value = localized_data[identifier_field]
          
          # Find or create record
          existing = model_class.find_by(identifier_field => identifier_value)
          
          if existing
            puts "  ⚠️  #{model_class.name} '#{identifier_value}' (#{locale}) already exists, skipping..."
          else
            model_class.create!(localized_data)
            puts "  ✅ Created #{model_class.name}: #{identifier_value} (#{locale})"
          end
        end
      end
    end
  end

  def self.puts_i18n_status
    if multilingual_enabled?
      puts "🌍 I18n enabled with locales: #{available_locales.join(', ')}"
    else
      puts "📝 I18n detected but only single locale (#{I18n.locale}) - using fallback content"
    end
  end
end