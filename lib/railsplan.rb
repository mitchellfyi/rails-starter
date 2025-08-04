# frozen_string_literal: true

require "railsplan/version"
require "railsplan/string_extensions"
require "railsplan/cli"
require "railsplan/generator"
require "railsplan/ruby_manager"
require "railsplan/rails_manager"
require "railsplan/app_generator"
require "railsplan/module_manager"
require "railsplan/logger"
require "railsplan/config"
require "railsplan/ai_config"
require "railsplan/context_manager"
require "railsplan/data_preview"
require "railsplan/ai_generator"
require "railsplan/ai"

# Only load web interface when Rails is available
if defined?(Rails) && defined?(Rails::Engine)
  require "railsplan/web"
end

# Main module for RailsPlan gem
module RailsPlan
  class Error < StandardError; end
  
  # Configuration instance
  def self.config
    @config ||= Config.new
  end
  
  # Logger instance
  def self.logger
    @logger ||= Logger.new
  end
  
  # Reset configuration and logger (mainly for testing)
  def self.reset!
    @config = nil
    @logger = nil
  end
end 