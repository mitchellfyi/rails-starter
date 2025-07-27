# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'pathname'

# RailsPlanManifest generates and manages the railsplan.json manifest file
# that tracks installed modules, their configurations, hooks, and metadata
class RailsPlanManifest
  MANIFEST_VERSION = '1.0.0'
  REGISTRY_PATH = File.expand_path('../scaffold/config/railsplan_modules.json', __dir__)
  MANIFEST_PATH = File.expand_path('../railsplan.json', __dir__)
  TEMPLATE_PATH = File.expand_path('../scaffold/lib/templates/railsplan', __dir__)
  
  # Module categories for organization
  CATEGORIES = {
    'auth' => 'core',
    'ai' => 'feature',
    'api' => 'feature',
    'admin' => 'feature',
    'mcp' => 'feature',
    'ai-multitenant' => 'feature',
    'billing' => 'feature',
    'cms' => 'feature',
    'workspace' => 'feature',
    'i18n' => 'feature',
    'notifications' => 'feature',
    'user_settings' => 'feature',
    'onboarding' => 'feature',
    'deploy' => 'tooling',
    'docs' => 'tooling',
    'theme' => 'ui',
    'flowbite' => 'ui'
  }.freeze
  
  # UI metadata for modules
  UI_METADATA = {
    'auth' => { icon: 'shield-check', color: 'blue', required: true, toggleable: false, admin_only: false },
    'ai' => { icon: 'cpu-chip', color: 'purple', required: false, toggleable: true, admin_only: false },
    'api' => { icon: 'code-bracket', color: 'green', required: false, toggleable: true, admin_only: false },
    'admin' => { icon: 'cog-6-tooth', color: 'red', required: false, toggleable: true, admin_only: true },
    'mcp' => { icon: 'squares-2x2', color: 'indigo', required: false, toggleable: true, admin_only: false },
    'ai-multitenant' => { icon: 'building-office', color: 'teal', required: false, toggleable: true, admin_only: false },
    'billing' => { icon: 'credit-card', color: 'emerald', required: false, toggleable: true, admin_only: false },
    'cms' => { icon: 'document-duplicate', color: 'amber', required: false, toggleable: true, admin_only: false },
    'workspace' => { icon: 'building-office-2', color: 'cyan', required: false, toggleable: true, admin_only: false },
    'deploy' => { icon: 'rocket-launch', color: 'orange', required: false, toggleable: true, admin_only: true },
    'docs' => { icon: 'document-text', color: 'gray', required: false, toggleable: true, admin_only: false },
    'theme' => { icon: 'paint-brush', color: 'pink', required: false, toggleable: true, admin_only: false },
    'flowbite' => { icon: 'sparkles', color: 'violet', required: false, toggleable: true, admin_only: false },
    'i18n' => { icon: 'language', color: 'blue', required: false, toggleable: true, admin_only: false },
    'notifications' => { icon: 'bell', color: 'yellow', required: false, toggleable: true, admin_only: false },
    'user_settings' => { icon: 'user-circle', color: 'slate', required: false, toggleable: true, admin_only: false },
    'onboarding' => { icon: 'academic-cap', color: 'sky', required: false, toggleable: true, admin_only: false }
  }.freeze
  
  def initialize(verbose: false)
    @verbose = verbose
  end
  
  # Generate the comprehensive railsplan.json manifest
  def generate!
    puts "📋 Generating railsplan.json manifest..." if @verbose
    
    manifest = {
      manifest_version: MANIFEST_VERSION,
      generated_at: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      railsplan_cli_version: detect_railsplan_cli_version,
      application: generate_application_info,
      modules: generate_modules_info,
      registry_metadata: generate_registry_metadata
    }
    
    FileUtils.mkdir_p(File.dirname(MANIFEST_PATH))
    File.write(MANIFEST_PATH, JSON.pretty_generate(manifest))
    
    puts "✅ Generated railsplan.json manifest at #{MANIFEST_PATH}" if @verbose
    manifest
  end
  
  # Load and parse the current manifest
  def load
    return {} unless File.exist?(MANIFEST_PATH)
    
    begin
      JSON.parse(File.read(MANIFEST_PATH), symbolize_names: true)
    rescue JSON::ParserError => e
      puts "⚠️  Warning: Could not parse railsplan.json: #{e.message}" if @verbose
      {}
    end
  end
  
  # Validate the manifest against current system state
  def validate!
    puts "🔍 Validating railsplan.json manifest..." if @verbose
    
    manifest = load
    errors = []
    warnings = []
    
    # Check manifest structure
    errors << "Missing manifest_version" unless manifest[:manifest_version]
    errors << "Missing modules section" unless manifest[:modules]
    
    # Validate each module
    if manifest[:modules]
      manifest[:modules].each do |module_name, module_info|
        module_errors = validate_module(module_name.to_s, module_info)
        errors.concat(module_errors)
      end
    end
    
    # Check for installed modules not in manifest
    registry = load_registry
    if registry['installed']
      registry['installed'].each_key do |module_name|
        unless manifest.dig(:modules, module_name.to_sym)
          warnings << "Module '#{module_name}' is installed but not in manifest"
        end
      end
    end
    
    # Report results
    if errors.empty? && warnings.empty?
      puts "✅ Manifest validation passed" if @verbose
      return { valid: true, errors: [], warnings: [] }
    else
      puts "❌ Manifest validation failed:" if @verbose
      errors.each { |error| puts "  Error: #{error}" if @verbose }
      warnings.each { |warning| puts "  Warning: #{warning}" if @verbose }
      return { valid: errors.empty?, errors: errors, warnings: warnings }
    end
  end
  
  # Check if a module is properly configured according to manifest
  def module_healthy?(module_name)
    manifest = load
    module_info = manifest.dig(:modules, module_name.to_sym)
    return false unless module_info
    
    # Check if files exist
    config_files_exist = check_config_files(module_name, module_info)
    dependencies_met = check_dependencies(module_name, module_info)
    migrations_applied = check_migrations(module_name, module_info)
    
    config_files_exist && dependencies_met && migrations_applied
  end
  
  # Get module information from manifest
  def module_info(module_name)
    manifest = load
    manifest.dig(:modules, module_name.to_sym)
  end
  
  # Get all modules by category
  def modules_by_category(category)
    manifest = load
    return [] unless manifest[:modules]
    
    manifest[:modules].select { |_, info| info[:category] == category }.keys.map(&:to_s)
  end
  
  # Get UI metadata for module management interface
  def ui_modules_data
    manifest = load
    return [] unless manifest[:modules]
    
    manifest[:modules].map do |module_name, info|
      {
        name: module_name.to_s,
        display_name: info.dig(:ui_metadata, :display_name) || simple_titleize(module_name.to_s),
        description: info[:description] || 'No description available',
        icon: info.dig(:ui_metadata, :icon) || 'cube',
        color: info.dig(:ui_metadata, :color) || 'gray',
        category: info[:category] || 'feature',
        status: info[:status] || 'unknown',
        required: info.dig(:ui_metadata, :required) || false,
        toggleable: info.dig(:ui_metadata, :toggleable) || true,
        admin_only: info.dig(:ui_metadata, :admin_only) || false,
        version: info[:version] || '1.0.0',
        installed_at: info[:installed_at],
        health_status: module_healthy?(module_name.to_s) ? 'healthy' : 'unhealthy'
      }
    end
  end
  
  private
  
  def detect_railsplan_cli_version
    railsplan_cli_path = File.expand_path('../bin/railsplan', __dir__)
    return '1.0.0' unless File.exist?(railsplan_cli_path)
    
    # Try to extract version from the CLI file
    content = File.read(railsplan_cli_path)
    version_match = content.match(/VERSION\s*=\s*['"]([^'"]+)['"]/)
    version_match ? version_match[1] : '1.0.0'
  end
  
  def generate_application_info
    {
      name: detect_app_name,
      ruby_version: RUBY_VERSION,
      rails_version: detect_rails_version,
      railsplan_path: "./scaffold"
    }
  end
  
  def detect_app_name
    # Try to extract from config/application.rb
    app_config_path = File.expand_path('../config/application.rb', __dir__)
    if File.exist?(app_config_path)
      content = File.read(app_config_path)
      match = content.match(/module\s+(\w+)/)
      return match[1] if match
    end
    
    # Fallback to directory name
    File.basename(File.expand_path('..', __dir__)).split(/[-_]/).map(&:capitalize).join(' ')
  end
  
  def detect_rails_version
    gemfile_path = File.expand_path('../Gemfile', __dir__)
    return '7.0+' unless File.exist?(gemfile_path)
    
    content = File.read(gemfile_path)
    rails_match = content.match(/gem\s+['"]rails['"],\s*['"]~>\s*([^'"]+)['"]/)
    rails_match ? "#{rails_match[1]}+" : '7.0+'
  end
  
  def generate_modules_info
    registry = load_registry
    modules = {}
    
    return modules unless registry['installed']
    
    registry['installed'].each do |module_name, registry_info|
      modules[module_name] = generate_module_info(module_name, registry_info)
    end
    
    modules
  end
  
  def generate_module_info(module_name, registry_info)
    template_path = registry_info['template_path'] || File.join(TEMPLATE_PATH, module_name)
    
    {
      version: registry_info['version'] || '1.0.0',
      status: 'installed',
      installed_at: registry_info['installed_at'],
      template_path: template_path,
      description: extract_module_description(module_name, template_path),
      category: CATEGORIES[module_name] || 'feature',
      dependencies: extract_module_dependencies(module_name, template_path),
      configurations: extract_module_configurations(module_name, template_path),
      hooks: extract_module_hooks(module_name, template_path),
      ui_metadata: generate_ui_metadata(module_name),
      health_checks: generate_health_checks(module_name, template_path)
    }
  end
  
  def extract_module_description(module_name, template_path)
    readme_path = File.join(template_path, 'README.md')
    return "No description available" unless File.exist?(readme_path)
    
    content = File.read(readme_path)
    # Extract first line that's not a header
    lines = content.split("\n")
    description_line = lines.find { |line| !line.start_with?('#') && line.strip.length > 0 }
    description_line&.strip || "#{simple_titleize(module_name)} module"
  rescue => e
    puts "Warning: Could not extract description for #{module_name}: #{e.message}" if @verbose
    "#{simple_titleize(module_name)} module"
  end
  
  def extract_module_dependencies(module_name, template_path)
    # For now, use known dependencies. Could be enhanced to parse install.rb
    case module_name
    when 'admin' then ['auth']
    when 'mcp' then ['ai']
    when 'ai-multitenant' then ['ai']
    else []
    end
  end
  
  def extract_module_configurations(module_name, template_path)
    configs = {
      initializers: [],
      routes: false,
      migrations: [],
      seeds: []
    }
    
    # Check for initializers
    initializers_path = File.join(template_path, 'config', 'initializers')
    if Dir.exist?(initializers_path)
      Dir.glob(File.join(initializers_path, '*.rb')).each do |file|
        relative_path = "config/initializers/#{File.basename(file)}"
        configs[:initializers] << relative_path
      end
    end
    
    # Check for routes
    routes_path = File.join(template_path, 'config', 'routes.rb')
    configs[:routes] = File.exist?(routes_path)
    
    # Check for migrations
    migrations_path = File.join(template_path, 'db', 'migrate')
    if Dir.exist?(migrations_path)
      Dir.glob(File.join(migrations_path, '*.rb')).each do |file|
        migration_name = File.basename(file, '.rb').gsub(/^\d+_/, '')
        configs[:migrations] << migration_name
      end
    end
    
    # Check for seeds
    seeds_path = File.join(template_path, 'db', 'seeds')
    if Dir.exist?(seeds_path)
      Dir.glob(File.join(seeds_path, '*.rb')).each do |file|
        relative_path = "db/seeds/#{File.basename(file)}"
        configs[:seeds] << relative_path
      end
    end
    
    configs
  end
  
  def extract_module_hooks(module_name, template_path)
    hooks = {
      install: { gems: [], before_install: [], after_install: [], files_created: [] },
      remove: { before_remove: [], after_remove: [], files_removed: [] }
    }
    
    # Parse install.rb for hooks
    install_path = File.join(template_path, 'install.rb')
    if File.exist?(install_path)
      content = File.read(install_path)
      
      # Extract gems
      gem_matches = content.scan(/add_gem\s+['"]([^'"]+)['"]/)
      hooks[:install][:gems] = gem_matches.flatten
      
      # Extract key files that would be created (simplified)
      case module_name
      when 'auth'
        hooks[:install][:files_created] = ['app/models/user.rb', 'app/controllers/application_controller.rb']
      when 'ai'
        hooks[:install][:files_created] = ['app/models/prompt_template.rb', 'app/controllers/prompt_templates_controller.rb']
      when 'api'
        hooks[:install][:files_created] = ['app/controllers/api_controller.rb']
      when 'admin'
        hooks[:install][:files_created] = ['app/controllers/admin_controller.rb']
      when 'mcp'
        hooks[:install][:files_created] = ['app/models/mcp/fetcher.rb']
      when 'deploy'
        hooks[:install][:files_created] = ['config/deploy.rb', 'Dockerfile']
      when 'theme'
        hooks[:install][:files_created] = ['app/assets/stylesheets/theme.css']
      when 'ai-multitenant'
        hooks[:install][:files_created] = ['app/models/ai_provider.rb', 'app/models/ai_credential.rb']
      when 'docs'
        hooks[:install][:files_created] = ['docs/README.md']
      end
      
      # Extract after_install hooks
      if content.include?('rails db:migrate')
        hooks[:install][:after_install] << 'rails db:migrate'
      end
      if content.include?('rails db:seed')
        hooks[:install][:after_install] << 'rails db:seed'
      end
      if content.include?('yarn install')
        hooks[:install][:after_install] << 'yarn install'
      end
      if content.include?('bin/railsplan docs')
        hooks[:install][:after_install] << 'bin/railsplan docs'
      end
    end
    
    hooks
  end
  
  def generate_ui_metadata(module_name)
    base_metadata = UI_METADATA[module_name] || {}
    {
      display_name: simple_titleize(module_name.gsub(/[-_]/, ' ')),
      icon: base_metadata[:icon] || 'cube',
      color: base_metadata[:color] || 'gray',
      required: base_metadata[:required] || false,
      toggleable: base_metadata[:toggleable] != false,
      admin_only: base_metadata[:admin_only] || false
    }
  end
  
  def generate_health_checks(module_name, template_path)
    {
      config_files_exist: check_config_files(module_name, nil),
      migrations_applied: check_migrations(module_name, nil),
      dependencies_met: check_dependencies(module_name, nil),
      api_keys_configured: check_api_keys(module_name)
    }
  end
  
  def check_config_files(module_name, module_info)
    # Check if key configuration files exist
    case module_name
    when 'ai'
      File.exist?(File.expand_path('../config/initializers/ai.rb', __dir__))
    when 'admin'
      File.exist?(File.expand_path('../config/initializers/admin.rb', __dir__))
    when 'mcp'
      File.exist?(File.expand_path('../config/initializers/mcp.rb', __dir__))
    else
      true # Assume config files exist for other modules
    end
  end
  
  def check_migrations(module_name, module_info)
    # For now, assume migrations are applied if the module is installed
    # Could be enhanced to actually check migration status
    true
  end
  
  def check_dependencies(module_name, module_info)
    # Check if module dependencies are installed
    registry = load_registry
    installed_modules = registry.dig('installed')&.keys || []
    
    case module_name
    when 'admin'
      installed_modules.include?('auth')
    when 'mcp'
      installed_modules.include?('ai')
    when 'ai-multitenant'
      installed_modules.include?('ai')
    else
      true
    end
  end
  
  def check_api_keys(module_name)
    # Check if required API keys are configured
    case module_name
    when 'ai', 'mcp', 'ai-multitenant'
      ENV['OPENAI_API_KEY'] && !ENV['OPENAI_API_KEY'].empty?
    else
      true # No API keys required
    end
  end
  
  def generate_registry_metadata
    registry = load_registry
    installed_modules = registry.dig('installed') || {}
    
    category_counts = Hash.new(0)
    installed_modules.each_key do |module_name|
      category = CATEGORIES[module_name] || 'feature'
      category_counts[category] += 1
    end
    
    {
      total_modules: installed_modules.size,
      installed_modules: installed_modules.size,
      core_modules: category_counts['core'],
      feature_modules: category_counts['feature'],
      ui_modules: category_counts['ui'],
      tooling_modules: category_counts['tooling'],
      last_validated: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      validation_status: 'healthy'
    }
  end
  
  def validate_module(module_name, module_info)
    errors = []
    
    errors << "Module '#{module_name}' missing version" unless module_info[:version]
    errors << "Module '#{module_name}' missing status" unless module_info[:status]
    errors << "Module '#{module_name}' missing template_path" unless module_info[:template_path]
    
    if module_info[:template_path] && !Dir.exist?(module_info[:template_path])
      errors << "Module '#{module_name}' template path does not exist: #{module_info[:template_path]}"
    end
    
    errors
  end
  
  def load_registry
    return { 'installed' => {} } unless File.exist?(REGISTRY_PATH)
    
    begin
      JSON.parse(File.read(REGISTRY_PATH))
    rescue JSON::ParserError
      { 'installed' => {} }
    end
  end
  
  # Simple titleize method since we don't have ActiveSupport
  def simple_titleize(str)
    str.split(/\s+/).map(&:capitalize).join(' ')
  end
end