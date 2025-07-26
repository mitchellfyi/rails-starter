# frozen_string_literal: true

require 'test_helper'

class LLMJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one) # Assumes fixtures exist
    @template = "Hello {{name}}, please tell me about {{topic}}"
    @model = "gpt-4"
    @context = { name: "Alice", topic: "Ruby on Rails" }
    @format = "text"
  end

  test "should queue job with default parameters" do
    assert_enqueued_with(
      job: LLMJob,
      args: [{
        template: @template,
        model: @model,
        context: @context,
        format: @format,
        user_id: @user.id,
        agent_id: nil
      }]
    ) do
      LLMJob.perform_later(
        template: @template,
        model: @model,
        context: @context,
        format: @format,
        user_id: @user.id
      )
    end
  end

  test "should create LLMOutput on successful execution" do
    assert_difference 'LLMOutput.count', 1 do
      LLMJob.perform_now(
        template: @template,
        model: @model,
        context: @context,
        format: @format,
        user_id: @user.id
      )
    end

    output = LLMOutput.last
    assert_equal @template, output.template_name
    assert_equal @model, output.model_name
    assert_equal @context.stringify_keys, output.context
    assert_equal @format, output.format
    assert_equal @user.id, output.user_id
    assert_equal 'completed', output.status
    assert_not_nil output.raw_response
    assert_not_nil output.parsed_output
    assert_not_nil output.prompt
  end

  test "should interpolate template variables" do
    output = LLMJob.perform_now(
      template: @template,
      model: @model,
      context: @context,
      format: @format,
      user_id: @user.id
    )

    expected_prompt = "Hello Alice, please tell me about Ruby on Rails"
    assert_equal expected_prompt, output.prompt
  end

  test "should handle different output formats" do
    # Test JSON format
    json_output = LLMJob.perform_now(
      template: @template,
      model: @model,
      context: @context,
      format: "json",
      user_id: @user.id
    )
    assert_equal "json", json_output.format
    assert json_output.raw_response.present?

    # Test markdown format
    md_output = LLMJob.perform_now(
      template: @template,
      model: @model,
      context: @context,
      format: "markdown",
      user_id: @user.id
    )
    assert_equal "markdown", md_output.format
    assert md_output.raw_response.start_with?("#")
  end

  test "should log job execution" do
    Rails.logger.expects(:info).at_least_once
    
    LLMJob.perform_now(
      template: @template,
      model: @model,
      context: @context,
      format: @format,
      user_id: @user.id
    )
  end

  test "should handle job failures and log errors" do
    # Mock an API failure
    LLMJob.any_instance.stubs(:call_llm_api).raises(StandardError, "API Error")
    Rails.logger.expects(:error).at_least_once

    assert_raises(StandardError) do
      LLMJob.perform_now(
        template: @template,
        model: @model,
        context: @context,
        format: @format,
        user_id: @user.id
      )
    end
  end

  test "should work without user_id" do
    assert_difference 'LLMOutput.count', 1 do
      LLMJob.perform_now(
        template: @template,
        model: @model,
        context: @context,
        format: @format
      )
    end

    output = LLMOutput.last
    assert_nil output.user_id
  end

  test "should handle empty context" do
    template = "Generate a random fact"
    
    output = LLMJob.perform_now(
      template: template,
      model: @model,
      context: {},
      format: @format,
      user_id: @user.id
    )

    assert_equal template, output.prompt
    assert_equal 'completed', output.status
  end

  test "should enrich context with MCP fetchers" do
    # Mock a simple fetcher
    mock_fetcher = Class.new do
      def self.fetch(user:, **)
        { additional_data: "extra context for #{user.name}" }
      end
    end
    
    Mcp::Registry.stubs(:get).with(:test_fetcher).returns(mock_fetcher)

    mcp_fetchers = [
      { key: :test_fetcher, params: {} }
    ]

    output = LLMJob.perform_now(
      template: "Hello {{name}}, {{additional_data}}",
      model: @model,
      context: { name: "Alice" },
      user_id: @user.id,
      mcp_fetchers: mcp_fetchers
    )

    # Check that the MCP data was included
    assert_includes output.prompt, "extra context for"
    assert output.context.key?('additional_data')
  end

  test "should handle MCP fetcher failures gracefully" do
    # Mock a failing fetcher
    mock_fetcher = Class.new do
      def self.fetch(**)
        raise StandardError, "Fetcher failed"
      end
    end
    
    Mcp::Registry.stubs(:get).with(:failing_fetcher).returns(mock_fetcher)

    mcp_fetchers = [
      { key: :failing_fetcher, params: {} }
    ]

    # Should not raise error
    assert_nothing_raised do
      LLMJob.perform_now(
        template: @template,
        model: @model,
        context: @context,
        user_id: @user.id,
        mcp_fetchers: mcp_fetchers
      )
    end
  end

  test "should work without MCP fetchers" do
    # Ensure backward compatibility
    output = LLMJob.perform_now(
      template: @template,
      model: @model,
      context: @context,
      format: @format,
      user_id: @user.id
    )

    assert_equal 'completed', output.status
    assert_includes output.prompt, "Alice"
  end
end