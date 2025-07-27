# frozen_string_literal: true

require "test_helper"

class ParanoidModeTest < ActiveSupport::TestCase
  def setup
    @original_paranoid_mode = ParanoidMode.config.enabled
    @original_force_https = ParanoidMode.config.force_https
  end
  
  def teardown
    ParanoidMode.config.enabled = @original_paranoid_mode
    ParanoidMode.config.force_https = @original_force_https
  end
  
  test "paranoid mode can be enabled via configuration" do
    ParanoidMode.config.enabled = true
    assert ParanoidMode.enabled?
  end
  
  test "paranoid mode can be enabled via environment variable" do
    ENV['PARANOID_MODE'] = 'true'
    assert ParanoidMode.enabled?
  ensure
    ENV.delete('PARANOID_MODE')
  end
  
  test "paranoid mode is disabled by default" do
    ParanoidMode.config.enabled = false
    ENV.delete('PARANOID_MODE')
    refute ParanoidMode.enabled?
  end
  
  test "session timeout is configurable" do
    assert_equal 30.minutes, ParanoidMode.config.session_timeout
    
    ParanoidMode.config.session_timeout = 1.hour
    assert_equal 1.hour, ParanoidMode.config.session_timeout
  end
  
  test "admin 2FA is required by default in paranoid mode" do
    assert ParanoidMode.config.admin_2fa_required
  end
  
  test "CSP configuration is properly structured" do
    csp = ParanoidMode.config.content_security_policy
    assert_includes csp[:default_src], "'self'"
    assert_includes csp[:object_src], "'none'"
    assert_includes csp[:script_src], "'self'"
  end
  
  test "HSTS configuration has reasonable defaults" do
    assert_equal 31_536_000, ParanoidMode.config.hsts_max_age # 1 year
    assert ParanoidMode.config.hsts_include_subdomains
    assert ParanoidMode.config.hsts_preload
  end
  
  test "development mode adjustments work correctly" do
    assert ParanoidMode.development_mode? if Rails.env.development?
    refute ParanoidMode.config.force_https if Rails.env.development? && ENV['PARANOID_FORCE_HTTPS'].blank?
  end
end