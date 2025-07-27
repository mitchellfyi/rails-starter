# frozen_string_literal: true

require 'test_helper'

class EnvironmentImportServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test@example.com",
      password: "password",
      first_name: "Test",
      last_name: "User"
    )
    
    @workspace = Workspace.create!(
      name: "Test Workspace",
      slug: "test-workspace",
      created_by: @user
    )
    
    @ai_provider = AiProvider.create!(
      name: "OpenAI",
      slug: "openai",
      api_base_url: "https://api.openai.com",
      supported_models: ["gpt-4", "gpt-3.5-turbo"]
    )
    
    @service = EnvironmentImportService.new(@workspace, @user)
  end

  test "should import from valid mappings" do
    ENV.stub(:[]) do |key|
      case key
      when 'OPENAI_API_KEY'
        'sk-test1234567890abcdefghijklmnopqrstuvwxyz'
      else
        nil
      end
    end
    
    mappings = [
      {
        enabled: true,
        env_key: "OPENAI_API_KEY",
        env_source: "environment",
        provider_id: @ai_provider.id,
        name: "OpenAI Test",
        model: "gpt-4",
        temperature: 0.7,
        max_tokens: 4096,
        response_format: "text",
        test_immediately: false
      }
    ]
    
    result = @service.import_from_mappings(mappings)
    
    assert result[:success]
    assert_equal 1, result[:imported_count]
    assert_empty result[:errors]
    
    credential = @workspace.ai_credentials.last
    assert_equal "OpenAI Test", credential.name
    assert_equal "OPENAI_API_KEY", credential.environment_source
    assert_equal @user, credential.imported_by
    assert_not_nil credential.imported_at
  end

  test "should skip disabled mappings" do
    mappings = [
      {
        enabled: false,
        env_key: "OPENAI_API_KEY",
        provider_id: @ai_provider.id
      }
    ]
    
    result = @service.import_from_mappings(mappings)
    
    assert result[:success]
    assert_equal 0, result[:imported_count]
  end

  test "should handle missing environment variables" do
    mappings = [
      {
        enabled: true,
        env_key: "MISSING_API_KEY",
        env_source: "environment",
        provider_id: @ai_provider.id,
        name: "Missing Test"
      }
    ]
    
    result = @service.import_from_mappings(mappings)
    
    refute result[:success]
    assert_equal 0, result[:imported_count]
    assert_includes result[:errors].first, "not set or empty"
  end

  test "should import from single env key" do
    ENV.stub(:[]) do |key|
      case key
      when 'TEST_API_KEY'
        'sk-test1234567890abcdefghijklmnopqrstuvwxyz'
      else
        nil
      end
    end
    
    credential = @service.import_from_env_key('TEST_API_KEY', @ai_provider.id, 'Custom Name')
    
    assert credential.persisted?
    assert_equal 'Custom Name', credential.name
    assert_equal 'TEST_API_KEY', credential.environment_source
    assert_equal @user, credential.imported_by
  end

  test "should generate unique names for duplicate credentials" do
    # Create existing credential
    existing = AiCredential.create!(
      workspace: @workspace,
      ai_provider: @ai_provider,
      name: "OpenAI (TEST_API_KEY)",
      api_key: "sk-existing123",
      preferred_model: "gpt-4",
      temperature: 0.7,
      max_tokens: 1000,
      response_format: "text"
    )
    
    ENV.stub(:[]) do |key|
      case key
      when 'TEST_API_KEY'
        'sk-test1234567890abcdefghijklmnopqrstuvwxyz'
      else
        nil
      end
    end
    
    credential = @service.import_from_env_key('TEST_API_KEY', @ai_provider.id)
    
    assert credential.persisted?
    refute_equal existing.name, credential.name
    assert_includes credential.name, Time.current.strftime('%Y%m%d')
  end

  test "should validate api key format during import" do
    ENV.stub(:[]) do |key|
      case key
      when 'INVALID_API_KEY'
        'invalid-key-format'
      else
        nil
      end
    end
    
    assert_raises(RuntimeError, match: /invalid/) do
      @service.import_from_env_key('INVALID_API_KEY', @ai_provider.id)
    end
  end

  test "should bulk import detected variables" do
    ENV.stub(:[]) do |key|
      case key
      when 'OPENAI_API_KEY'
        'sk-test1234567890abcdefghijklmnopqrstuvwxyz'
      when 'ANTHROPIC_API_KEY'
        'sk-ant-api03-test1234567890abcdef'
      else
        nil
      end
    end
    
    # Create Anthropic provider
    anthropic = AiProvider.create!(
      name: "Anthropic",
      slug: "anthropic",
      api_base_url: "https://api.anthropic.com",
      supported_models: ["claude-3-haiku-20240307"]
    )
    
    # Mock scanner to return detected variables
    mock_scanner = Minitest::Mock.new
    detected_vars = {
      'OPENAI_API_KEY' => { provider: 'openai', source: 'environment' },
      'ANTHROPIC_API_KEY' => { provider: 'anthropic', source: 'environment' }
    }
    suggestions = [
      {
        env_key: 'OPENAI_API_KEY',
        provider: @ai_provider,
        suggested_name: 'OpenAI (Imported)',
        suggested_model: 'gpt-4'
      },
      {
        env_key: 'ANTHROPIC_API_KEY',
        provider: anthropic,
        suggested_name: 'Anthropic (Imported)',
        suggested_model: 'claude-3-haiku-20240307'
      }
    ]
    
    mock_scanner.expect :scan_environment_variables, detected_vars
    mock_scanner.expect :suggest_credential_mappings, suggestions, [detected_vars]
    
    EnvironmentScannerService.stub :new, mock_scanner do
      result = @service.bulk_import_detected_variables
      
      assert result[:success]
      assert_equal 2, result[:imported_count]
      assert_empty result[:errors]
    end
    
    mock_scanner.verify
  end

  test "should parse env file values correctly" do
    # Create test .env file
    File.write('.env.test', <<~ENV)
      TEST_KEY=simple_value
      QUOTED_KEY="quoted_value"
      SINGLE_QUOTED='single_quoted'
      SPACED_KEY= spaced_value 
    ENV
    
    File.stub(:exist?) { |path| path == '.env.test' }
    
    assert_equal 'simple_value', @service.send(:parse_env_file_value, '.env.test', 'TEST_KEY')
    assert_equal 'quoted_value', @service.send(:parse_env_file_value, '.env.test', 'QUOTED_KEY')
    assert_equal 'single_quoted', @service.send(:parse_env_file_value, '.env.test', 'SINGLE_QUOTED')
    assert_equal 'spaced_value', @service.send(:parse_env_file_value, '.env.test', 'SPACED_KEY')
    assert_nil @service.send(:parse_env_file_value, '.env.test', 'MISSING_KEY')
    
    # Cleanup
    File.delete('.env.test') if File.exist?('.env.test')
  end

  test "should suggest appropriate default models" do
    openai = AiProvider.create!(slug: "openai", name: "OpenAI", supported_models: ["gpt-4"])
    anthropic = AiProvider.create!(slug: "anthropic", name: "Anthropic", supported_models: ["claude-3-haiku-20240307"])
    unknown = AiProvider.create!(slug: "unknown", name: "Unknown", supported_models: ["custom-model"])
    
    assert_equal 'gpt-4', @service.send(:suggest_default_model, openai)
    assert_equal 'claude-3-haiku-20240307', @service.send(:suggest_default_model, anthropic)
    assert_equal 'custom-model', @service.send(:suggest_default_model, unknown)
  end

  test "should get env value from environment or files" do
    ENV.stub(:[]) do |key|
      case key
      when 'ENV_VAR'
        'env_value'
      else
        nil
      end
    end
    
    # Test environment variable
    assert_equal 'env_value', @service.send(:get_env_value, 'ENV_VAR', 'environment')
    
    # Test missing variable
    assert_nil @service.send(:get_env_value, 'MISSING_VAR', 'environment')
    
    # Test file source
    File.write('.env.test', "FILE_VAR=file_value\n")
    File.stub(:exist?) { |path| path == '.env.test' }
    
    assert_equal 'file_value', @service.send(:get_env_value, 'FILE_VAR', '.env.test:1')
    
    # Cleanup
    File.delete('.env.test') if File.exist?('.env.test')
  end
end