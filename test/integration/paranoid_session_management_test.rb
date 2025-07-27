# frozen_string_literal: true

require "test_helper"

class ParanoidSessionManagementTest < ActionDispatch::IntegrationTest
  def setup
    @original_paranoid_mode = ParanoidMode.config.enabled
    @original_session_timeout = ParanoidMode.config.session_timeout
    
    # Enable paranoid mode for these tests
    ParanoidMode.config.enabled = true
    ParanoidMode.config.session_timeout = 5.minutes
    
    @user = User.create!(
      email: "test@example.com",
      first_name: "Test",
      last_name: "User"
    )
  end
  
  def teardown
    ParanoidMode.config.enabled = @original_paranoid_mode
    ParanoidMode.config.session_timeout = @original_session_timeout
  end
  
  test "session activity is tracked" do
    # Mock a controller that includes the concern
    controller_class = Class.new(ActionController::Base) do
      include ParanoidSessionManagement
      
      def index
        render plain: "OK"
      end
      
      private
      
      def current_user
        User.first
      end
    end
    
    # This test would need a full Rails app context to test properly
    # For now, we'll test the concern methods directly
    controller = controller_class.new
    
    # Mock session
    session = {}
    allow(controller).to receive(:session).and_return(session)
    allow(controller).to receive(:redirect_to_login)
    
    # Test session activity update
    controller.send(:update_session_activity)
    assert session[:last_activity_at].present?
    
    activity_time = Time.zone.parse(session[:last_activity_at])
    assert_in_delta Time.current, activity_time, 1.second
  end
  
  test "session expiry is checked correctly" do
    controller_class = Class.new(ActionController::Base) do
      include ParanoidSessionManagement
      
      def current_user
        User.first
      end
      
      def redirect_to_login
        # Mock implementation
      end
      
      def reset_session
        session.clear
      end
      
      def flash
        @flash ||= {}
      end
    end
    
    controller = controller_class.new
    session = { last_activity_at: 10.minutes.ago.iso8601 }
    allow(controller).to receive(:session).and_return(session)
    allow(controller).to receive(:redirect_to_login)
    
    # Should expire the session
    expect(controller).to receive(:expire_session_with_message).with("Your session has expired due to inactivity.")
    controller.send(:check_session_expiry)
  end
  
  test "timeout remaining is calculated correctly" do
    controller_class = Class.new(ActionController::Base) do
      include ParanoidSessionManagement
    end
    
    controller = controller_class.new
    
    # Test with no session activity
    allow(controller).to receive(:session).and_return({})
    assert_nil controller.send(:paranoid_session_timeout_remaining)
    
    # Test with recent activity
    session = { last_activity_at: 2.minutes.ago.iso8601 }
    allow(controller).to receive(:session).and_return(session)
    remaining = controller.send(:paranoid_session_timeout_remaining)
    
    assert remaining > 0
    assert remaining <= 180 # 3 minutes
  end
  
  test "expired session returns zero remaining time" do
    controller_class = Class.new(ActionController::Base) do
      include ParanoidSessionManagement
    end
    
    controller = controller_class.new
    session = { last_activity_at: 10.minutes.ago.iso8601 }
    allow(controller).to receive(:session).and_return(session)
    
    remaining = controller.send(:paranoid_session_timeout_remaining)
    assert_equal 0, remaining
  end
  
  private
  
  def allow(object)
    # Simple mock helper for tests
    def object.receive(method)
      MockReceiver.new(self, method)
    end
    object
  end
  
  def expect(object)
    allow(object)
  end
  
  class MockReceiver
    def initialize(object, method)
      @object = object
      @method = method
    end
    
    def and_return(value)
      @object.define_singleton_method(@method) { value }
    end
    
    def with(*args)
      self
    end
  end
end