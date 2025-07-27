# frozen_string_literal: true

require "json"
require "digest"
require "time"

module RailsPlan
  # Manages application context extraction and storage
  class ContextManager
    CONTEXT_DIR = ".railsplan"
    CONTEXT_FILE = "context.json"
    SETTINGS_FILE = "settings.yml"
    PROMPTS_LOG = "prompts.log"
    LAST_GENERATED_DIR = "last_generated"
    TMP_DIR = "tmp"
    
    attr_reader :context_path, :settings_path, :prompts_log_path
    
    def initialize(app_root = Dir.pwd)
      @app_root = app_root
      @context_dir = File.join(@app_root, CONTEXT_DIR)
      @context_path = File.join(@context_dir, CONTEXT_FILE)
      @settings_path = File.join(@context_dir, SETTINGS_FILE)
      @prompts_log_path = File.join(@context_dir, PROMPTS_LOG)
      @last_generated_dir = File.join(@context_dir, LAST_GENERATED_DIR)
      @tmp_dir = File.join(@context_dir, TMP_DIR)
    end
    
    def setup_directory
      FileUtils.mkdir_p(@context_dir)
      FileUtils.mkdir_p(@last_generated_dir)
      FileUtils.mkdir_p(@tmp_dir)
      
      # Create .gitignore for railsplan directory
      gitignore_path = File.join(@context_dir, ".gitignore")
      unless File.exist?(gitignore_path)
        File.write(gitignore_path, "tmp/\n*.log\nlast_generated/\n")
      end
    end
    
    def extract_context
      setup_directory
      
      context = {
        "generated_at" => Time.now.iso8601,
        "app_name" => extract_app_name,
        "models" => extract_models,
        "schema" => extract_schema,
        "routes" => extract_routes,
        "controllers" => extract_controllers,
        "modules" => extract_modules,
        "hash" => nil # Will be calculated after extraction
      }
      
      # Calculate hash for change detection
      context_for_hash = context.dup
      context_for_hash.delete("generated_at")
      context_for_hash.delete("hash")
      context_string = context_for_hash.to_json
      context["hash"] = Digest::SHA256.hexdigest(context_string)
      
      File.write(@context_path, JSON.pretty_generate(context))
      
      context
    end
    
    def load_context
      return nil unless File.exist?(@context_path)
      
      JSON.parse(File.read(@context_path))
    rescue JSON::ParserError
      nil
    end
    
    def context_stale?
      context = load_context
      return true unless context
      
      # Check if schema or models have changed
      current_hash = calculate_current_hash
      is_stale = context["hash"] != current_hash
      
      # Debug output for testing
      if ENV["DEBUG_CONTEXT"]
        puts "Stored hash: #{context["hash"]}"
        puts "Current hash: #{current_hash}"
        puts "Is stale: #{is_stale}"
      end
      
      is_stale
    end
    
    def log_prompt(prompt, response, metadata = {})
      setup_directory
      
      log_entry = {
        timestamp: Time.now.iso8601,
        prompt: prompt,
        response: response,
        metadata: metadata
      }
      
      File.open(@prompts_log_path, "a") do |f|
        f.puts JSON.generate(log_entry)
      end
    end
    
    def save_last_generated(files)
      setup_directory
      FileUtils.rm_rf(@last_generated_dir)
      FileUtils.mkdir_p(@last_generated_dir)
      
      files.each do |file_path, content|
        full_path = File.join(@last_generated_dir, file_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
      end
    end
    
    def load_settings
      return {} unless File.exist?(@settings_path)
      
      YAML.safe_load(File.read(@settings_path)) || {}
    rescue StandardError
      {}
    end
    
    def save_settings(settings)
      setup_directory
      File.write(@settings_path, YAML.dump(settings))
    end
    
    private
    
    def extract_app_name
      # Try to get from Rails application if available
      if defined?(Rails) && Rails.application
        Rails.application.class.module_parent_name.underscore
      else
        # Fall back to directory name
        File.basename(@app_root)
      end
    end
    
    def extract_models
      models = []
      models_dir = File.join(@app_root, "app/models")
      
      return models unless Dir.exist?(models_dir)
      
      Dir.glob("#{models_dir}/**/*.rb").each do |file|
        content = File.read(file)
        model_info = parse_model_file(file, content)
        models << model_info if model_info
      end
      
      models
    end
    
    def extract_schema
      schema_file = File.join(@app_root, "db/schema.rb")
      return {} unless File.exist?(schema_file)
      
      schema_content = File.read(schema_file)
      parse_schema(schema_content)
    end
    
    def extract_routes
      routes = []
      
      # Try to get routes from Rails if available
      if defined?(Rails) && Rails.application
        begin
          require "rails/application"
          Rails.application.reload_routes! if Rails.application.routes.routes.empty?
          
          Rails.application.routes.routes.each do |route|
            routes << {
              verb: route.verb,
              path: route.path.spec.to_s,
              controller: route.defaults[:controller],
              action: route.defaults[:action],
              name: route.name
            }
          end
        rescue StandardError => e
          RailsPlan.logger.debug("Could not extract routes: #{e.message}")
        end
      end
      
      routes
    end
    
    def extract_controllers
      controllers = []
      controllers_dir = File.join(@app_root, "app/controllers")
      
      return controllers unless Dir.exist?(controllers_dir)
      
      Dir.glob("#{controllers_dir}/**/*.rb").each do |file|
        content = File.read(file)
        controller_info = parse_controller_file(file, content)
        controllers << controller_info if controller_info
      end
      
      controllers
    end
    
    def extract_modules
      modules = []
      modules_file = File.join(@app_root, "config/railsplan_modules.json")
      
      if File.exist?(modules_file)
        begin
          module_data = JSON.parse(File.read(modules_file))
          modules = module_data["installed"]&.keys || []
        rescue JSON::ParserError
          # Ignore
        end
      end
      
      modules
    end
    
    def parse_model_file(file, content)
      relative_path = file.sub(@app_root + "/", "")
      class_name = classify(File.basename(file, ".rb"))
      
      # Extract basic information
      associations = extract_associations(content)
      validations = extract_validations(content)
      scopes = extract_scopes(content)
      
      {
        file: relative_path,
        class_name: class_name,
        associations: associations,
        validations: validations,
        scopes: scopes
      }
    end
    
    def parse_controller_file(file, content)
      relative_path = file.sub(@app_root + "/", "")
      class_name = classify(File.basename(file, ".rb"))
      
      # Extract actions
      actions = content.scan(/def\s+([a-zA-Z_][a-zA-Z0-9_]*!)?\s*$/).flatten.compact
      
      {
        file: relative_path,
        class_name: class_name,
        actions: actions
      }
    end
    
    def parse_schema(content)
      tables = {}
      
      # Extract table definitions with more flexible regex
      content.scan(/create_table\s+["']([^"']+)["'][^{]*do\s*\|t\|(.*?)end/m) do |table_name, table_content|
        columns = {}
        
        # Extract column definitions
        table_content.scan(/t\.(\w+)\s+["']([^"']+)["']/) do |type, name|
          columns[name] = { "type" => type, "options" => nil }
        end
        
        # Also try without quotes for some formats
        table_content.scan(/t\.(\w+)\s+:([a-zA-Z_][a-zA-Z0-9_]*)/) do |type, name|
          columns[name] = { "type" => type, "options" => nil }
        end
        
        tables[table_name] = { "columns" => columns } if columns.any?
      end
      
      tables
    end
    
    def extract_associations(content)
      associations = []
      
      # belongs_to
      content.scan(/belongs_to\s+:([a-zA-Z_][a-zA-Z0-9_]*)/) do |match|
        associations << { type: "belongs_to", name: match[0] }
      end
      
      # has_many
      content.scan(/has_many\s+:([a-zA-Z_][a-zA-Z0-9_]*)/) do |match|
        associations << { type: "has_many", name: match[0] }
      end
      
      # has_one
      content.scan(/has_one\s+:([a-zA-Z_][a-zA-Z0-9_]*)/) do |match|
        associations << { type: "has_one", name: match[0] }
      end
      
      associations
    end
    
    def extract_validations(content)
      validations = []
      
      content.scan(/validates?\s+:([a-zA-Z_][a-zA-Z0-9_]*),?\s*([^\n]+)/) do |field, rules|
        validations << { field: field, rules: rules.strip }
      end
      
      validations
    end
    
    def extract_scopes(content)
      scopes = []
      
      content.scan(/scope\s+:([a-zA-Z_][a-zA-Z0-9_]*),?\s*([^\n]+)/) do |name, definition|
        scopes << { name: name, definition: definition.strip }
      end
      
      scopes
    end
    
    def calculate_current_hash
      current_context = {
        "models" => extract_models,
        "schema" => extract_schema,
        "routes" => extract_routes,
        "controllers" => extract_controllers,
        "modules" => extract_modules
      }
      
      Digest::SHA256.hexdigest(current_context.to_json)
    end
    
    # Simple Rails-like string inflections for when Rails isn't available
    def classify(string)
      string.split('_').map(&:capitalize).join
    end
  end
end