# frozen_string_literal: true

require "test_helper"

class RailsplanWebEngineTest < ActiveSupport::TestCase
  test "engine is defined" do
    assert defined?(Railsplan::Web::Engine)
  end
  
  test "engine is isolated namespace" do
    assert_equal Railsplan::Web, Railsplan::Web::Engine.isolated_namespace
  end
  
  test "engine routes are loaded" do
    engine_routes = Railsplan::Web::Engine.routes.routes
    assert engine_routes.any?
  end
end