# frozen_string_literal: true

# Standalone test helper for running tests without full Rails environment
# This is used when Rails dependencies are not available

require 'minitest/autorun'
require 'minitest/pride'

# Load gem modules without Rails
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# Try to load railsplan components that don't require Rails
begin
  require 'railsplan/version'
  require 'railsplan/string_extensions'
  require 'railsplan/logger'
  require 'railsplan/config'
rescue LoadError => e
  puts "⚠️  Warning: Could not load some RailsPlan components: #{e.message}"
end

class StandaloneTestCase < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("railsplan_test")
    @original_dir = Dir.pwd
  end

  def teardown
    Dir.chdir(@original_dir) if @original_dir
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end
end