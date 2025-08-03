# frozen_string_literal: true

require "yaml"
require "erb"
require "fileutils"

module RailsPlan
  # Manages AI provider configuration
  class AIConfig
    DEFAULT_CONFIG_PATH = File.expand_path("~/.railsplan/ai.yml")
    PROJECT_CONFIG_PATH = ".railsplan/ai.yml"
    LEGACY_PROJECT_CONFIG_PATH = ".railsplanrc"
    
    attr_reader :provider, :model, :api_key, :profile
    
    def initialize(profile: nil, provider: nil)
      @profile = profile || "default"
      @override_provider = provider
      load_configuration
    end
    
    def configured?
      case @provider
      when "cursor"
        # Cursor doesn't need API key, just needs to be available
        true
      else
        !@api_key.nil? && !@api_key.empty?
      end
    end
    
    def openai?
      @provider == "openai"
    end
    
    def anthropic?
      @provider == "anthropic"
    end
    
    def gemini?
      @provider == "gemini"
    end
    
    def cursor?
      @provider == "cursor"
    end
    
    def client
      return @client if @client
      
      case @provider
      when "openai"
        require "openai"
        @client = OpenAI::Client.new(access_token: @api_key)
      when "anthropic"
        require "anthropic"
        @client = Anthropic::Client.new(api_key: @api_key)
      when "gemini"
        # Gemini doesn't use a client gem, return the API key
        @client = @api_key
      when "cursor"
        # Cursor doesn't use HTTP client
        @client = nil
      else
        raise RailsPlan::Error, "Unsupported AI provider: #{@provider}"
      end
    end
    
    def self.setup_config_file
      config_dir = File.dirname(DEFAULT_CONFIG_PATH)
      FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
      
      unless File.exist?(DEFAULT_CONFIG_PATH)
        sample_config = <<~YAML
          # RailsPlan AI Provider Configuration
          # Supports multiple providers: openai, claude, gemini, cursor
          
          provider: openai
          model: gpt-4o
          openai_api_key: <%= ENV['OPENAI_API_KEY'] %>
          claude_api_key: <%= ENV['ANTHROPIC_API_KEY'] %>
          gemini_api_key: <%= ENV['GOOGLE_API_KEY'] %>
          
          # Alternative configuration using profiles
          # profiles:
          #   development:
          #     provider: openai
          #     model: gpt-4o-mini
          #     openai_api_key: <%= ENV['OPENAI_API_KEY'] %>
          #   production:
          #     provider: claude
          #     model: claude-3-5-sonnet-20241022
          #     claude_api_key: <%= ENV['ANTHROPIC_API_KEY'] %>
          #   experimental:
          #     provider: gemini
          #     model: gemini-1.5-pro
          #     gemini_api_key: <%= ENV['GOOGLE_API_KEY'] %>
          #   local:
          #     provider: cursor
          #     # Cursor doesn't require API keys
        YAML
        
        File.write(DEFAULT_CONFIG_PATH, sample_config)
      end
      
      DEFAULT_CONFIG_PATH
    end
    
    private
    
    def load_configuration
      config = {}
      
      # Load from project-specific config first (.railsplan/ai.yml)
      if File.exist?(PROJECT_CONFIG_PATH)
        project_config = load_yaml_file(PROJECT_CONFIG_PATH)
        config.merge!(project_config || {})
      end
      
      # Load from legacy project config (.railsplanrc)
      if config.empty? && File.exist?(LEGACY_PROJECT_CONFIG_PATH)
        legacy_config = load_yaml_file(LEGACY_PROJECT_CONFIG_PATH)
        config.merge!(legacy_config["ai"] || {}) if legacy_config
      end
      
      # Load from user global config
      if File.exist?(DEFAULT_CONFIG_PATH)
        user_config = load_yaml_file(DEFAULT_CONFIG_PATH)
        
        if user_config
          # Check for new format vs legacy format
          if user_config.key?("profiles") && @profile != "default"
            # New format with profiles
            profile_config = user_config["profiles"]&.dig(@profile) || {}
            config = profile_config.merge(config) # Project config takes precedence
          elsif user_config.key?("provider")
            # New simple format
            config = user_config.merge(config) # Project config takes precedence
          else
            # Legacy format
            if @profile != "default" && user_config["profiles"]&.key?(@profile)
              profile_config = user_config["profiles"][@profile]
              config = profile_config.merge(config)
            else
              default_config = user_config["default"] || {}
              config = default_config.merge(config)
            end
          end
        end
      end
      
      # Apply override provider if specified
      if @override_provider
        config["provider"] = @override_provider.to_s
      end
      
      # Set configuration values
      @provider = config["provider"] || ENV["RAILSPLAN_AI_PROVIDER"] || "openai"
      @model = config["model"] || ENV["RAILSPLAN_AI_MODEL"] || default_model
      @api_key = determine_api_key(config)
    end
    
    def load_yaml_file(path)
      yaml_content = File.read(path)
      erb_content = ERB.new(yaml_content).result
      YAML.safe_load(erb_content)
    rescue => e
      RailsPlan.logger.warn("Failed to load config file #{path}: #{e.message}") if defined?(RailsPlan.logger)
      nil
    end
    
    def determine_api_key(config)
      # Try provider-specific key first
      provider_key = "#{@provider}_api_key"
      api_key = config[provider_key]
      
      # Fall back to generic api_key
      api_key ||= config["api_key"]
      
      # Fall back to environment variables
      api_key || fallback_api_key
    end
    
    def default_model
      case @provider
      when "openai"
        "gpt-4o"
      when "anthropic"
        "claude-3-5-sonnet-20241022"
      when "gemini"
        "gemini-1.5-pro"
      when "cursor"
        "cursor-local"
      else
        "gpt-4o"
      end
    end
    
    def fallback_api_key
      case @provider
      when "openai"
        ENV["OPENAI_API_KEY"]
      when "anthropic"
        ENV["ANTHROPIC_API_KEY"] || ENV["CLAUDE_KEY"]
      when "gemini"
        ENV["GOOGLE_API_KEY"] || ENV["GOOGLE_GENERATIVE_AI_API_KEY"]
      when "cursor"
        nil # Cursor doesn't need API key
      else
        nil
      end
    end
  end
end