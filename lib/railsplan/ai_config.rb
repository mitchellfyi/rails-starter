# frozen_string_literal: true

require "yaml"
require "erb"

module RailsPlan
  # Manages AI provider configuration
  class AIConfig
    DEFAULT_CONFIG_PATH = File.expand_path("~/.railsplan/ai.yml")
    PROJECT_CONFIG_PATH = ".railsplanrc"
    
    attr_reader :provider, :model, :api_key, :profile
    
    def initialize(profile: "default")
      @profile = profile
      load_configuration
    end
    
    def configured?
      !@api_key.nil? && !@api_key.empty?
    end
    
    def openai?
      @provider == "openai"
    end
    
    def anthropic?
      @provider == "anthropic"
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
      else
        raise RailsPlan::Error, "Unsupported AI provider: #{@provider}"
      end
    end
    
    def self.setup_config_file
      config_dir = File.dirname(DEFAULT_CONFIG_PATH)
      FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)
      
      unless File.exist?(DEFAULT_CONFIG_PATH)
        sample_config = <<~YAML
          default:
            provider: openai
            model: gpt-4o
            api_key: <%= ENV['OPENAI_API_KEY'] %>
          profiles:
            test:
              provider: anthropic
              model: claude-3-sonnet
              api_key: <%= ENV['CLAUDE_KEY'] %>
            gpt35:
              provider: openai
              model: gpt-3.5-turbo
              api_key: <%= ENV['OPENAI_API_KEY'] %>
        YAML
        
        File.write(DEFAULT_CONFIG_PATH, sample_config)
      end
      
      DEFAULT_CONFIG_PATH
    end
    
    private
    
    def load_configuration
      config = {}
      
      # Load from project-specific config first
      if File.exist?(PROJECT_CONFIG_PATH)
        project_config = YAML.safe_load(ERB.new(File.read(PROJECT_CONFIG_PATH)).result) || {}
        config.merge!(project_config["ai"] || {})
      end
      
      # Load from user global config
      if File.exist?(DEFAULT_CONFIG_PATH)
        user_config = YAML.safe_load(ERB.new(File.read(DEFAULT_CONFIG_PATH)).result) || {}
        
        # Get profile-specific config
        if @profile != "default" && user_config["profiles"]&.key?(@profile)
          profile_config = user_config["profiles"][@profile]
          config = profile_config.merge(config) # Project config takes precedence
        else
          default_config = user_config["default"] || {}
          config = default_config.merge(config) # Project config takes precedence
        end
      end
      
      # Fall back to environment variables
      @provider = config["provider"] || ENV["RAILSPLAN_AI_PROVIDER"] || "openai"
      @model = config["model"] || ENV["RAILSPLAN_AI_MODEL"] || default_model
      @api_key = config["api_key"] || ENV["RAILSPLAN_AI_API_KEY"] || fallback_api_key
    end
    
    def default_model
      case @provider
      when "openai"
        "gpt-4o"
      when "anthropic"
        "claude-3-sonnet-20240229"
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
      else
        nil
      end
    end
  end
end