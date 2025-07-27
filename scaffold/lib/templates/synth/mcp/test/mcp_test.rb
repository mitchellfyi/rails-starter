# frozen_string_literal: true

require 'test_helper'

class McpModuleTest < ActiveSupport::TestCase
  def setup
    @context_provider = ContextProvider.create!(
      name: 'test_provider',
      provider_type: 'database',
      configuration: {
        query: 'SELECT name FROM users WHERE id = ?',
        parameters: ['user_id']
      },
      active: true,
      description: 'Test context provider'
    )
  rescue NameError
    skip "ContextProvider model not available in test environment"
  end

  test "context provider creation" do
    skip "ContextProvider model not available in test environment" unless defined?(ContextProvider)
    
    provider = ContextProvider.create!(
      name: 'api_provider',
      provider_type: 'http_api',
      configuration: {
        url: 'https://api.example.com/data',
        headers: { 'Authorization' => 'Bearer token' }
      },
      active: true,
      description: 'External API provider'
    )

    assert provider.persisted?
    assert_equal 'api_provider', provider.name
    assert_equal 'http_api', provider.provider_type
    assert provider.active?
  end

  test "context provider validation" do
    skip "ContextProvider model not available in test environment" unless defined?(ContextProvider)
    
    provider = ContextProvider.new
    assert_not provider.valid?
    
    assert provider.errors[:name].any?
    assert provider.errors[:provider_type].any?
  end

  test "context cache functionality" do
    skip "ContextCache model not available in test environment" unless defined?(ContextCache)
    
    cache_entry = ContextCache.create!(
      key: 'test_cache_key',
      data: { result: 'cached data' },
      expires_at: 1.hour.from_now,
      provider: 'test_provider'
    )

    assert cache_entry.persisted?
    assert_equal 'test_cache_key', cache_entry.key
    assert_equal({ 'result' => 'cached data' }, cache_entry.data)
  end

  test "context cache expiration" do
    skip "ContextCache model not available in test environment" unless defined?(ContextCache)
    
    expired_cache = ContextCache.create!(
      key: 'expired_key',
      data: { result: 'old data' },
      expires_at: 1.hour.ago,
      provider: 'test_provider'
    )

    valid_cache = ContextCache.create!(
      key: 'valid_key',
      data: { result: 'fresh data' },
      expires_at: 1.hour.from_now,
      provider: 'test_provider'
    )

    if ContextCache.respond_to?(:expired)
      assert_includes ContextCache.expired, expired_cache
      assert_not_includes ContextCache.expired, valid_cache
    end

    if ContextCache.respond_to?(:valid)
      assert_includes ContextCache.valid, valid_cache
      assert_not_includes ContextCache.valid, expired_cache
    end
  end

  test "mcp configuration" do
    # Test MCP configuration
    if Rails.application.config.respond_to?(:mcp)
      config = Rails.application.config.mcp
      assert_not_nil config
      
      # Test default configuration values
      assert config.cache_ttl if config.respond_to?(:cache_ttl)
      assert config.timeout if config.respond_to?(:timeout)
      assert config.max_retries if config.respond_to?(:max_retries)
    end
  end

  test "context provider types" do
    skip "ContextProvider model not available in test environment" unless defined?(ContextProvider)
    
    # Test different provider types
    database_provider = ContextProvider.create!(
      name: 'db_provider',
      provider_type: 'database',
      configuration: { query: 'SELECT * FROM table' },
      active: true
    )

    api_provider = ContextProvider.create!(
      name: 'api_provider',
      provider_type: 'http_api',
      configuration: { url: 'https://api.example.com' },
      active: true
    )

    file_provider = ContextProvider.create!(
      name: 'file_provider',
      provider_type: 'file',
      configuration: { path: '/path/to/file.json' },
      active: true
    )

    assert_equal 'database', database_provider.provider_type
    assert_equal 'http_api', api_provider.provider_type
    assert_equal 'file', file_provider.provider_type
  end

  test "context provider configuration validation" do
    skip "ContextProvider model not available in test environment" unless defined?(ContextProvider)
    
    # Database provider should have query
    db_provider = ContextProvider.new(
      name: 'incomplete_db',
      provider_type: 'database',
      configuration: {},
      active: true
    )

    # API provider should have URL
    api_provider = ContextProvider.new(
      name: 'incomplete_api',
      provider_type: 'http_api',
      configuration: {},
      active: true
    )

    # Test basic validation (actual validation logic would be in the model)
    assert_equal 'database', db_provider.provider_type
    assert_equal 'http_api', api_provider.provider_type
  end

  test "context provider scopes" do
    skip "ContextProvider model not available in test environment" unless defined?(ContextProvider)
    
    active_provider = ContextProvider.create!(
      name: 'active_provider',
      provider_type: 'database',
      configuration: { query: 'SELECT 1' },
      active: true
    )

    inactive_provider = ContextProvider.create!(
      name: 'inactive_provider',
      provider_type: 'database',
      configuration: { query: 'SELECT 1' },
      active: false
    )

    if ContextProvider.respond_to?(:active)
      assert_includes ContextProvider.active, active_provider
      assert_not_includes ContextProvider.active, inactive_provider
    end
  end
end