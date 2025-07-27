# frozen_string_literal: true

require "railsplan/version"
require "railsplan/cli"
require "railsplan/generator"
require "railsplan/ruby_manager"
require "railsplan/rails_manager"
require "railsplan/app_generator"
require "railsplan/module_manager"
require "railsplan/logger"
require "railsplan/config"

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