# frozen_string_literal: true

require "test_helper"

class Railsplan::Web::DashboardControllerTest < ActionDispatch::IntegrationTest
  include Engine.routes.url_helpers
  
  def setup
    # Create .railsplan directory for tests
    FileUtils.mkdir_p(Rails.root.join('.railsplan'))
    
    # Create basic context.json for testing
    context = {
      "generated_at" => Time.current.iso8601,
      "app_name" => "test_app",
      "models" => []
    }
    File.write(Rails.root.join('.railsplan/context.json'), JSON.generate(context))
  end
  
  def teardown
    # Clean up test files
    FileUtils.rm_rf(Rails.root.join('.railsplan'))
  end
  
  test "should get dashboard index" do
    get railsplan_web.root_path
    assert_response :success
    assert_select "h1", text: "RailsPlan Dashboard"
  end
  
  test "should display Ruby version" do
    get railsplan_web.root_path
    assert_response :success
    assert_select "text", RUBY_VERSION
  end
  
  test "should display Rails version" do
    get railsplan_web.root_path
    assert_response :success
    assert_select "text", Rails::VERSION::STRING
  end
  
  test "should show not initialized view when .railsplan missing" do
    FileUtils.rm_rf(Rails.root.join('.railsplan'))
    
    get railsplan_web.root_path
    assert_response :success
    assert_select "h1", text: "RailsPlan Not Initialized"
  end

  private
  
  def Engine
    Railsplan::Web::Engine
  end
end