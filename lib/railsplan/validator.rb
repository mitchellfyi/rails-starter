# frozen_string_literal: true

require "json"
require "pathname"
require "time"

module RailsPlan
  # Validates module completeness and system-level guarantees
  class Validator
    attr_reader :errors, :warnings, :logger

    def initialize(logger: nil)
      @logger = logger || RailsPlan.logger
      @errors = []
      @warnings = []
    end

    # Validate all installed modules
    def validate_all_modules(app_path = ".")
      @logger.info("Validating all modules in #{app_path}")
      
      modules = get_installed_modules(app_path)
      results = {}
      
      modules.each do |module_name|
        results[module_name] = validate_module(module_name, app_path)
      end
      
      results
    end

    # Validate a specific module for completeness
    def validate_module(module_name, app_path = ".")
      @logger.debug("Validating module: #{module_name}")
      
      reset_errors_and_warnings
      module_path = File.join(app_path, "lib", "railsplan", "modules", module_name)
      
      # Check if module exists
      unless Dir.exist?(module_path)
        add_error("Module directory not found: #{module_path}")
        return validation_result(module_name)
      end

      # Validate required components
      validate_module_structure(module_name, module_path, app_path)
      validate_i18n_keys(module_name, app_path)
      validate_accessibility_tags(module_name, app_path)
      validate_seo_metadata(module_name, app_path)
      validate_tests(module_name, app_path)
      validate_documentation(module_name, app_path)
      validate_migrations(module_name, app_path)
      validate_audit_logging(module_name, app_path)
      validate_context_registration(module_name, app_path)
      
      validation_result(module_name)
    end

    # Validate system-wide consistency
    def validate_system_consistency(app_path = ".")
      @logger.info("Validating system consistency")
      
      reset_errors_and_warnings
      
      validate_context_freshness(app_path)
      validate_prompt_logs_consistency(app_path)
      validate_uncommitted_diffs(app_path)
      validate_install_uninstall_hooks(app_path)
      
      {
        errors: @errors,
        warnings: @warnings,
        passed: @errors.empty?
      }
    end

    private

    def reset_errors_and_warnings
      @errors = []
      @warnings = []
    end

    def add_error(message)
      @errors << message
      @logger.error(message)
    end

    def add_warning(message)
      @warnings << message
      @logger.warn(message)
    end

    def validation_result(module_name)
      {
        module: module_name,
        errors: @errors.dup,
        warnings: @warnings.dup,
        passed: @errors.empty?
      }
    end

    def get_installed_modules(app_path)
      modules_registry = File.join(app_path, ".railsplan", "modules.json")
      
      if File.exist?(modules_registry)
        begin
          registry = JSON.parse(File.read(modules_registry))
          registry["installed"]&.keys || []
        rescue JSON::ParserError
          add_warning("Failed to parse modules registry: #{modules_registry}")
          []
        end
      else
        # Fallback: scan lib/railsplan/modules directory
        modules_dir = File.join(app_path, "lib", "railsplan", "modules")
        if Dir.exist?(modules_dir)
          Dir.entries(modules_dir).select do |entry|
            next if entry.start_with?(".")
            Dir.exist?(File.join(modules_dir, entry))
          end
        else
          []
        end
      end
    end

    def validate_module_structure(module_name, module_path, app_path)
      required_files = [
        "install.rb",
        "remove.rb", 
        "README.md",
        "VERSION"
      ]
      
      required_files.each do |file|
        file_path = File.join(module_path, file)
        unless File.exist?(file_path)
          add_error("Missing required file: #{file} in module #{module_name}")
        end
      end

      # Check for self-contained structure
      unless Dir.exist?(File.join(module_path, "lib"))
        add_warning("Module #{module_name} should have lib/ directory for self-containment")
      end
    end

    def validate_i18n_keys(module_name, app_path)
      # Check for I18n files
      i18n_path = File.join(app_path, "config", "locales", "#{module_name}.yml")
      unless File.exist?(i18n_path)
        add_error("Missing I18n file: #{i18n_path}")
        return
      end

      # Basic validation of I18n structure
      begin
        require "yaml"
        i18n_content = YAML.load_file(i18n_path)
        unless i18n_content.is_a?(Hash) && i18n_content["en"]
          add_error("Invalid I18n structure in #{i18n_path}")
        end
      rescue => e
        add_error("Failed to parse I18n file #{i18n_path}: #{e.message}")
      end
    end

    def validate_accessibility_tags(module_name, app_path)
      # Scan view files for accessibility attributes
      views_pattern = File.join(app_path, "app", "views", "**", "*.html.erb")
      view_files = Dir.glob(views_pattern).select { |f| f.include?(module_name) }
      
      if view_files.empty?
        add_warning("No view files found for module #{module_name}")
        return
      end

      view_files.each do |view_file|
        content = File.read(view_file)
        
        # Check for basic accessibility attributes
        has_aria = content.include?("aria-") || content.include?("role=")
        has_alt = content.include?("alt=") if content.include?("<img")
        
        unless has_aria
          add_warning("View #{view_file} missing accessibility attributes (aria-*, role)")
        end
        
        if content.include?("<img") && !has_alt
          add_error("View #{view_file} has images without alt attributes")
        end
      end
    end

    def validate_seo_metadata(module_name, app_path)
      # Check for SEO-related files and metadata
      seo_indicators = [
        File.join(app_path, "app", "controllers", "**", "*#{module_name}*_controller.rb"),
        File.join(app_path, "app", "views", "**", "*#{module_name}*", "*.html.erb")
      ]
      
      has_seo_content = false
      
      seo_indicators.each do |pattern|
        Dir.glob(pattern).each do |file|
          content = File.read(file)
          if content.include?("meta") || content.include?("title") || content.include?("description")
            has_seo_content = true
            break
          end
        end
      end
      
      unless has_seo_content
        add_warning("Module #{module_name} appears to lack SEO metadata (title, meta tags)")
      end
    end

    def validate_tests(module_name, app_path)
      # Check for test files
      test_patterns = [
        File.join(app_path, "test", "**", "*#{module_name}*_test.rb"),
        File.join(app_path, "spec", "**", "*#{module_name}*_spec.rb")
      ]
      
      has_tests = test_patterns.any? { |pattern| Dir.glob(pattern).any? }
      
      unless has_tests
        add_error("Missing tests for module #{module_name}")
      end
    end

    def validate_documentation(module_name, app_path)
      # Check for documentation
      doc_files = [
        File.join(app_path, "docs", "#{module_name}.md"),
        File.join(app_path, "docs", "modules", "#{module_name}.md"),
        File.join(app_path, "lib", "railsplan", "modules", module_name, "README.md")
      ]
      
      has_docs = doc_files.any? { |file| File.exist?(file) }
      
      unless has_docs
        add_error("Missing documentation for module #{module_name}")
      end
    end

    def validate_migrations(module_name, app_path)
      # Check if module has migrations and they're properly structured
      migration_pattern = File.join(app_path, "db", "migrate", "*#{module_name}*.rb")
      migrations = Dir.glob(migration_pattern)
      
      migrations.each do |migration|
        content = File.read(migration)
        unless content.include?("class") && content.include?("def change")
          add_error("Migration #{migration} appears to be malformed")
        end
      end
    end

    def validate_audit_logging(module_name, app_path)
      # Check for audit logging in controllers/models
      code_patterns = [
        File.join(app_path, "app", "controllers", "**", "*#{module_name}*_controller.rb"),
        File.join(app_path, "app", "models", "**", "*#{module_name}*.rb")
      ]
      
      has_audit_logging = false
      
      code_patterns.each do |pattern|
        Dir.glob(pattern).each do |file|
          content = File.read(file)
          if content.include?("audit_log") || content.include?("AuditLog") || content.include?("log_activity")
            has_audit_logging = true
            break
          end
        end
      end
      
      unless has_audit_logging
        add_warning("Module #{module_name} missing audit logging for user-facing actions")
      end
    end

    def validate_context_registration(module_name, app_path)
      context_file = File.join(app_path, ".railsplan", "context.json")
      
      if File.exist?(context_file)
        begin
          context = JSON.parse(File.read(context_file))
          modules = context["modules"] || []
          
          unless modules.include?(module_name)
            add_warning("Module #{module_name} not registered in .railsplan/context.json")
          end
        rescue JSON::ParserError
          add_error("Failed to parse .railsplan/context.json")
        end
      else
        add_warning("Missing .railsplan/context.json file")
      end
    end

    def validate_context_freshness(app_path)
      context_file = File.join(app_path, ".railsplan", "context.json")
      
      if File.exist?(context_file)
        begin
          context = JSON.parse(File.read(context_file))
          generated_at = Time.parse(context["generated_at"])
          
          if Time.now - generated_at > 7 * 24 * 60 * 60  # 7 days
            add_warning(".railsplan/context.json is stale (older than 7 days)")
          end
        rescue JSON::ParserError, ArgumentError
          add_error("Failed to parse .railsplan/context.json timestamp")
        end
      else
        add_warning("Missing .railsplan/context.json - run 'railsplan index'")
      end
    end

    def validate_prompt_logs_consistency(app_path)
      prompts_log = File.join(app_path, ".railsplan", "prompts.log")
      
      if File.exist?(prompts_log)
        # Basic validation that logs are readable
        begin
          content = File.read(prompts_log)
          if content.empty?
            add_warning(".railsplan/prompts.log is empty")
          end
        rescue => e
          add_error("Failed to read .railsplan/prompts.log: #{e.message}")
        end
      else
        add_warning("Missing .railsplan/prompts.log - AI interactions not logged")
      end
    end

    def validate_uncommitted_diffs(app_path)
      return unless Dir.exist?(File.join(app_path, ".git"))
      
      # Check for uncommitted changes in .railsplan directory
      railsplan_dir = File.join(app_path, ".railsplan")
      return unless Dir.exist?(railsplan_dir)
      
      begin
        status_output = `cd "#{app_path}" && git status --porcelain .railsplan/ 2>/dev/null`.strip
        unless status_output.empty?
          add_warning("Uncommitted changes in .railsplan/ directory")
        end
      rescue => e
        add_warning("Could not check git status: #{e.message}")
      end
    end

    def validate_install_uninstall_hooks(app_path)
      modules = get_installed_modules(app_path)
      
      modules.each do |module_name|
        module_path = File.join(app_path, "lib", "railsplan", "modules", module_name)
        
        install_script = File.join(module_path, "install.rb")
        remove_script = File.join(module_path, "remove.rb")
        
        unless File.exist?(install_script)
          add_error("Module #{module_name} missing install.rb script")
        end
        
        unless File.exist?(remove_script)
          add_error("Module #{module_name} missing remove.rb script")
        end
      end
    end
  end
end