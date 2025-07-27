# I18n Configuration for multilingual seed content

# Add Spanish locale to available locales for demonstration
Rails.application.configure do
  config.i18n.available_locales = [:en, :es]
  config.i18n.default_locale = :en
end