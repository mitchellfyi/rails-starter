# frozen_string_literal: true

# Add app/domains to Rails autoload paths
Rails.application.config.to_prepare do
  Rails.application.config.paths.add 'app/domains', eager_load: true

  # Eager load all subdirectories within app/domains
  Dir.glob(Rails.root.join('app/domains/*')).each do |dir|
    Rails.application.config.paths.add dir, eager_load: true
    # Add common Rails subdirectories within each domain
    %w[controllers models services jobs mailers policies queries].each do |sub_dir|
      path = File.join(dir, 'app', sub_dir)
      Rails.application.config.paths.add path, eager_load: true if Dir.exist?(path)
    end
  end
end
