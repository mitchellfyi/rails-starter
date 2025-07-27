# frozen_string_literal: true

require 'test_helper'

class EnvironmentScannerServiceTest < ActiveSupport::TestCase
  setup do
    @service = EnvironmentScannerService.new
  end

  test "should detect openai api key from environment" do
    ENV.stub(:[]) do |key|
      case key
      when 'OPENAI_API_KEY'
        'sk-test1234567890abcdefghij'
      else
        nil
      end
    end
    
    detected = @service.scan_environment_variables
    
    assert detected['OPENAI_API_KEY']
    assert_equal 'openai', detected['OPENAI_API_KEY'][:provider]
    assert_equal 'environment', detected['OPENAI_API_KEY'][:source]
    assert_includes detected['OPENAI_API_KEY'][:value], 'sk-t'
    assert_includes detected['OPENAI_API_KEY'][:value], '***'
  end

  test "should detect anthropic api key from environment" do
    ENV.stub(:[]) do |key|
      case key
      when 'ANTHROPIC_API_KEY'
        'sk-ant-api03-test1234567890abcdef'
      else
        nil
      end
    end
    
    detected = @service.scan_environment_variables
    
    assert detected['ANTHROPIC_API_KEY']
    assert_equal 'anthropic', detected['ANTHROPIC_API_KEY'][:provider]
  end

  test "should scan env files for api keys" do
    # Create temporary .env file
    File.write('.env.test', <<~ENV)
      # Test environment file
      OPENAI_API_KEY=sk-test1234567890abcdefghij
      ANTHROPIC_API_KEY=sk-ant-api03-test1234567890abcdef
      DATABASE_URL=postgres://localhost/test
    ENV
    
    # Mock File.exist? to return true for our test file
    File.stub(:exist?) do |path|
      path == '.env.test' || path == '.env'
    end
    
    # Mock File.readlines to read our test file
    File.stub(:readlines) do |path|
      if path == '.env.test'
        File.readlines('.env.test')
      else
        []
      end
    end
    
    detected = @service.scan_env_files
    
    assert detected['OPENAI_API_KEY']
    assert detected['ANTHROPIC_API_KEY']
    refute detected['DATABASE_URL'] # Should not detect non-AI keys
    
    # Cleanup
    File.delete('.env.test') if File.exist?('.env.test')
  end

  test "should suggest credential mappings" do
    detected_vars = {
      'OPENAI_API_KEY' => {
        value: 'sk-t***ghij',
        provider: 'openai',
        source: 'environment'
      },
      'ANTHROPIC_API_KEY' => {
        value: 'sk-a***cdef',
        provider: 'anthropic',
        source: '.env:2'
      }
    }
    
    # Create test providers
    openai = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    anthropic = AiProvider.create!(
      name: "Anthropic",
      slug: "anthropic",
      api_base_url: "https://api.anthropic.com",
      supported_models: ["claude-3-haiku-20240307"]
    )
    
    suggestions = @service.suggest_credential_mappings(detected_vars)
    
    assert_equal 2, suggestions.length
    
    openai_suggestion = suggestions.find { |s| s[:provider] == openai }
    assert openai_suggestion
    assert_equal 'OPENAI_API_KEY', openai_suggestion[:env_key]
    assert_equal 'OpenAI (Imported)', openai_suggestion[:suggested_name]
    assert_equal 'gpt-4', openai_suggestion[:suggested_model]
    
    anthropic_suggestion = suggestions.find { |s| s[:provider] == anthropic }
    assert anthropic_suggestion
    assert_equal 'ANTHROPIC_API_KEY', anthropic_suggestion[:env_key]
    assert_equal 'Anthropic (Imported)', anthropic_suggestion[:suggested_name]
    assert_equal 'claude-3-haiku-20240307', anthropic_suggestion[:suggested_model]
  end

  test "should validate api key formats" do
    # Valid OpenAI key
    assert @service.validate_api_key_format('openai', 'sk-1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKL')
    
    # Invalid OpenAI key (too short)
    refute @service.validate_api_key_format('openai', 'sk-short')
    
    # Invalid OpenAI key (wrong prefix)
    refute @service.validate_api_key_format('openai', 'invalid-key')
    
    # Valid Anthropic key
    assert @service.validate_api_key_format('anthropic', 'sk-ant-api03-1234567890abcdef')
    
    # Invalid Anthropic key
    refute @service.validate_api_key_format('anthropic', 'sk-wrong-format')
    
    # Unknown provider (basic length check)
    assert @service.validate_api_key_format('unknown', 'long-enough-key-12345')
    refute @service.validate_api_key_format('unknown', 'short')
  end

  test "should mask secrets properly" do
    # Test short value
    assert_equal '****', @service.send(:mask_secret, 'test')
    
    # Test medium value
    assert_equal 'te***st', @service.send(:mask_secret, 'test123')
    
    # Test long value
    assert_equal 'sk-t***ghij', @service.send(:mask_secret, 'sk-test1234567890abcdefghij')
    
    # Test empty value
    assert_equal '', @service.send(:mask_secret, '')
    assert_equal '', @service.send(:mask_secret, nil)
  end

  test "should generate appropriate credential names" do
    provider = AiProvider.create!(
      name: "Test Provider",
      slug: "test",
      api_base_url: "https://api.test.com",
      supported_models: ["test-model"]
    )
    
    # Basic name
    assert_equal 'Test Provider (Imported)', 
                 @service.send(:generate_credential_name, provider, 'TEST_API_KEY')
    
    # Production key
    assert_equal 'Test Provider (Production)', 
                 @service.send(:generate_credential_name, provider, 'TEST_PRODUCTION_API_KEY')
    
    # Development key
    assert_equal 'Test Provider (Development)', 
                 @service.send(:generate_credential_name, provider, 'TEST_DEV_API_KEY')
    
    # Test key
    assert_equal 'Test Provider (Test)', 
                 @service.send(:generate_credential_name, provider, 'TEST_TEST_API_KEY')
  end

  test "should suggest default models for providers" do
    openai = AiProvider.create!(
      name: "OpenAI", 
      slug: "openai",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    anthropic = AiProvider.create!(
      name: "Anthropic", 
      slug: "anthropic",
      supported_models: ["claude-3-haiku-20240307"]
    )
    
    unknown = AiProvider.create!(
      name: "Unknown", 
      slug: "unknown",
      supported_models: ["unknown-model"]
    )
    
    assert_equal 'gpt-4', @service.send(:suggest_default_model, openai)
    assert_equal 'claude-3-haiku-20240307', @service.send(:suggest_default_model, anthropic)
    assert_equal 'unknown-model', @service.send(:suggest_default_model, unknown)
  end
end