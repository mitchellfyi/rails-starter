#!/usr/bin/env ruby
# Debug script for docs generation

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "railsplan/context_manager"

begin
  puts "Testing context loading..."
  context_manager = RailsPlan::ContextManager.new
  context = context_manager.load_context
  puts "Context loaded: #{context ? 'yes' : 'no'}"
  
  if context
    puts "Context keys: #{context.keys}"
    puts "Routes structure: #{context['routes']}"
    puts "Routes class: #{context['routes'].class}"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.join("\n")
end