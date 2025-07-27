# frozen_string_literal: true

# Test helpers for theme module testing
require 'ostruct'

# Minimal Rails template method implementations for testing
def after_bundle(&block)
  block.call if block_given?
end

def create_file(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

def prepend_to_file(path, content)
  if File.exist?(path)
    existing_content = File.read(path)
    File.write(path, content + existing_content)
  end
end

def say_status(type, message)
  # Silent for tests unless debugging
  puts "#{type}: #{message}" if ENV['THEME_TEST_VERBOSE']
end

def run(command)
  # For tests, just create the directories that mkdir commands would create
  if command.start_with?('mkdir -p')
    dir_path = command.gsub('mkdir -p ', '')
    FileUtils.mkdir_p(dir_path)
  end
end

# Mock File.exist? check for asset pipeline
class << File
  alias_method :original_exist?, :exist?
  
  def exist?(path)
    # For theme tests, simulate asset existence
    if path.include?('app/assets/stylesheets/application.tailwind.css')
      false
    else
      original_exist?(path)
    end
  end
end