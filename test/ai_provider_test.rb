# frozen_string_literal: true

require "test_helper"
require "railsplan/ai"
require "webmock/minitest"

class AIProviderTest < ActiveSupport::TestCase
  def setup
    # Enable WebMock for HTTP mocking
    WebMock.enable!
    
    # Create test config directory
    @test_config_dir = "/tmp/railsplan_test_#{SecureRandom.hex(8)}"
    FileUtils.mkdir_p(@test_config_dir)
    
    # Mock the config path
    stub_const(RailsPlan::AIConfig, :DEFAULT_CONFIG_PATH, File.join(@test_config_dir, "ai.yml"))
  end
  
  def teardown
    # Clean up test config
    FileUtils.rm_rf(@test_config_dir) if @test_config_dir && Dir.exist?(@test_config_dir)
    
    # Disable WebMock
    WebMock.disable!
  end
  
  test "AI.available_providers includes all supported providers" do
    expected_providers = [:openai, :claude, :gemini, :cursor]
    assert_equal expected_providers, RailsPlan::AI.available_providers
  end
  
  test "AI.call validates provider parameter" do
    assert_raises(ArgumentError, "Unsupported provider") do
      RailsPlan::AI.call(
        provider: :unknown_provider,
        prompt: "test"
      )
    end
  end
  
  test "AI.call validates prompt parameter" do
    assert_raises(ArgumentError, "Prompt cannot be nil or empty") do
      RailsPlan::AI.call(
        provider: :openai,
        prompt: ""
      )
    end
  end
  
  test "AI.call validates format parameter" do
    assert_raises(ArgumentError, "Unsupported format") do
      RailsPlan::AI.call(
        provider: :openai,
        prompt: "test",
        format: :unknown_format
      )
    end
  end
  
  test "OpenAI provider handles API response correctly" do
    # Create test config
    config_content = <<~YAML
      provider: openai
      openai_api_key: test_api_key
      model: gpt-4o
    YAML
    File.write(File.join(@test_config_dir, "ai.yml"), config_content)
    
    # Mock OpenAI API response
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                content: "Test response"
              },
              finish_reason: "stop"
            }
          ],
          usage: {
            prompt_tokens: 10,
            completion_tokens: 5,
            total_tokens: 15
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Mock the OpenAI client
    openai_client = Minitest::Mock.new
    openai_client.expect(:chat, {
      "choices" => [{
        "message" => { "content" => "Test response" },
        "finish_reason" => "stop"
      }],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }, [Hash])
    
    # Mock the AI config to return our mock client
    RailsPlan::AIConfig.any_instance.stubs(:configured?).returns(true)
    RailsPlan::AIConfig.any_instance.stubs(:provider).returns("openai")
    RailsPlan::AIConfig.any_instance.stubs(:model).returns("gpt-4o")
    RailsPlan::AIConfig.any_instance.stubs(:client).returns(openai_client)
    
    result = RailsPlan::AI.call(
      provider: :openai,
      prompt: "test prompt"
    )
    
    assert_equal "Test response", result[:output]
    assert_equal 15, result[:metadata][:tokens_used]
    assert result[:metadata][:success]
    
    openai_client.verify
  end
  
  test "Gemini provider makes correct HTTP request" do
    # Create test config
    config_content = <<~YAML
      provider: gemini
      gemini_api_key: test_api_key
      model: gemini-1.5-pro
    YAML
    File.write(File.join(@test_config_dir, "ai.yml"), config_content)
    
    # Mock Gemini API response
    stub_request(:post, /generativelanguage\.googleapis\.com/)
      .to_return(
        status: 200,
        body: {
          candidates: [
            {
              content: {
                parts: [
                  { text: "Gemini test response" }
                ]
              },
              finishReason: "STOP"
            }
          ],
          usageMetadata: {
            promptTokenCount: 8,
            candidatesTokenCount: 4,
            totalTokenCount: 12
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    result = RailsPlan::AI.call(
      provider: :gemini,
      prompt: "test prompt"
    )
    
    assert_equal "Gemini test response", result[:output]
    assert_equal 12, result[:metadata][:tokens_used]
    assert result[:metadata][:success]
  end
  
  test "format validation works for JSON output" do
    # Test valid JSON
    assert_nothing_raised do
      RailsPlan::AI.send(:validate_output, '{"test": "value"}', :json)
    end
    
    # Test invalid JSON
    assert_raises(RailsPlan::Error, "AI output is not valid JSON") do
      RailsPlan::AI.send(:validate_output, 'invalid json', :json)
    end
  end
  
  test "format validation works for Ruby output" do
    # Test valid Ruby
    assert_nothing_raised do
      RailsPlan::AI.send(:validate_output, 'puts "Hello World"', :ruby)
    end
    
    # Test invalid Ruby
    assert_raises(RailsPlan::Error, "AI output is not valid Ruby") do
      RailsPlan::AI.send(:validate_output, 'invalid ruby syntax {', :ruby)
    end
  end
  
  test "fallback provider logic works correctly" do
    fallback = RailsPlan::AI.send(:get_fallback_provider, :openai)
    assert_equal :claude, fallback
    
    fallback = RailsPlan::AI.send(:get_fallback_provider, :claude)
    assert_equal :openai, fallback
    
    fallback = RailsPlan::AI.send(:get_fallback_provider, :gemini)
    assert_equal :openai, fallback
  end
  
  private
  
  def stub_const(klass, const_name, value)
    original_value = klass.const_get(const_name)
    klass.send(:remove_const, const_name)
    klass.const_set(const_name, value)
    
    # Store for cleanup
    @stubbed_constants ||= []
    @stubbed_constants << [klass, const_name, original_value]
  end
end