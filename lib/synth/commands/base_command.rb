# frozen_string_literal: true

module Synth
  module Commands
    # Base class for all Synth CLI commands
    class BaseCommand
      TEMPLATE_PATH = File.expand_path('lib/templates/synth', Rails.root)
      REGISTRY_PATH = File.expand_path('config/synth_modules.json', Rails.root)
      
      attr_reader :verbose

      def initialize(verbose: false)
        @verbose = verbose
      end

      protected

      def log_verbose(message)
        puts message if verbose
      end

      def load_registry
        return { 'installed' => {} } unless File.exist?(REGISTRY_PATH)
        
        begin
          JSON.parse(File.read(REGISTRY_PATH))
        rescue JSON::ParserError
          log_verbose "⚠️  Registry file corrupted, resetting..."
          { 'installed' => {} }
        end
      end

      def save_registry(registry)
        FileUtils.mkdir_p(File.dirname(REGISTRY_PATH))
        File.write(REGISTRY_PATH, JSON.pretty_generate(registry))
      end

      def update_registry(module_name, info)
        registry = load_registry
        registry['installed'] ||= {}
        registry['installed'][module_name] = info
        save_registry(registry)
      end

      def module_installed?(module_name)
        registry = load_registry
        registry.dig('installed', module_name) != nil
      end

      def log_module_action(action, module_name, message = nil)
        log_file = 'log/synth.log'
        FileUtils.mkdir_p(File.dirname(log_file))
        
        File.open(log_file, 'a') do |f|
          timestamp = Time.current.iso8601
          log_message = "[#{timestamp}] [#{action.to_s.upcase}] Module: #{module_name}"
          log_message += " - #{message}" if message
          f.puts log_message
        end
      end

      def force_mode?
        ARGV.include?('--force') || ARGV.include?('-f')
      end

      def valid_module_name?(name)
        name.match?(/\A[a-z0-9_-]+\z/)
      end

      def get_available_modules
        return [] unless Dir.exist?(TEMPLATE_PATH)
        
        Dir.children(TEMPLATE_PATH).filter_map do |module_name|
          module_path = File.join(TEMPLATE_PATH, module_name)
          next unless File.directory?(module_path)
          
          readme_path = File.join(module_path, 'README.md')
          description = if File.exist?(readme_path)
            File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '') || 'No description'
          else
            'No description'
          end
          
          { name: module_name, description: description }
        end
      end

      def show_available_modules
        puts '📦 Available modules:'
        
        unless Dir.exist?(TEMPLATE_PATH)
          puts '  (templates directory not found)'
          return
        end

        modules = Dir.children(TEMPLATE_PATH).select { |d| File.directory?(File.join(TEMPLATE_PATH, d)) }
        
        if modules.empty?
          puts '  (no modules found)'
          return
        end

        modules.sort.each do |module_name|
          module_path = File.join(TEMPLATE_PATH, module_name)
          readme_path = File.join(module_path, 'README.md')
          version_path = File.join(module_path, 'VERSION')
          
          description = if File.exist?(readme_path)
            File.readlines(readme_path).first&.strip&.gsub(/^#\s*/, '') || 'No description'
          else
            'No description'
          end
          
          version = if File.exist?(version_path)
            File.read(version_path).strip
          else
            'unknown'
          end
          
          installed = module_installed?(module_name)
          status_icon = installed ? '✅' : '  '
          
          puts "  #{status_icon} #{module_name.ljust(15)} v#{version.ljust(8)} - #{description}"
        end
      end

      def show_installed_modules
        puts '🔧 Installed modules:'
        
        registry = load_registry
        installed_modules = registry['installed'] || {}
        
        if installed_modules.empty?
          puts '  (no modules installed)'
          return
        end

        installed_modules.each do |module_name, info|
          version = info['version'] || 'unknown'
          installed_at = info['installed_at'] ? info['installed_at'][0..9] : 'unknown'
          puts "  ✅ #{module_name.ljust(15)} v#{version.ljust(8)} (installed: #{installed_at})"
        end
      end
    end
  end
end