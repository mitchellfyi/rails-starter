# frozen_string_literal: true

# Test helper for LLM-related testing
module LLMTestHelper
  # Mock LLM API responses for testing
  def mock_llm_response(model:, format: 'text', success: true)
    if success
      case format
      when 'json'
        {
          raw: '{"response": "Mock JSON response", "model": "' + model + '"}',
          parsed: { "response" => "Mock JSON response", "model" => model }
        }
      when 'markdown'
        {
          raw: "# Mock Markdown Response\n\nGenerated by #{model}",
          parsed: "# Mock Markdown Response\n\nGenerated by #{model}"
        }
      when 'html'
        {
          raw: "<h1>Mock HTML Response</h1><p>Generated by #{model}</p>",
          parsed: "<h1>Mock HTML Response</h1><p>Generated by #{model}</p>"
        }
      else
        {
          raw: "Mock text response generated by #{model}",
          parsed: "Mock text response generated by #{model}"
        }
      end
    else
      raise StandardError, "Mock API error for testing"
    end
  end

  # Create a test LLMOutput record
  def create_test_llm_output(user: nil, **attributes)
    default_attributes = {
      template_name: "Test template {{name}}",
      model_name: "gpt-4",
      context: { name: "Alice" },
      format: "text",
      status: "completed",
      job_id: SecureRandom.uuid,
      prompt: "Test template Alice",
      raw_response: "Hello Alice! This is a test response.",
      parsed_output: "Hello Alice! This is a test response."
    }

    if user
      default_attributes[:user_id] = user.id
    end

    LLMOutput.create!(default_attributes.merge(attributes))
  end

  # Assert that an LLM job was enqueued with specific parameters
  def assert_llm_job_enqueued(template:, model:, **options)
    expected_args = {
      template: template,
      model: model,
      context: options[:context] || {},
      format: options[:format] || 'text',
      user_id: options[:user_id],
      agent_id: options[:agent_id]
    }

    assert_enqueued_with(job: LLMJob, args: [expected_args]) do
      yield if block_given?
    end
  end

  # Stub LLM API calls for testing
  def stub_llm_api_success(format: 'text')
    LLMJob.any_instance.stubs(:call_llm_api).returns(
      mock_llm_response(model: 'gpt-4', format: format)
    )
  end

  def stub_llm_api_failure
    LLMJob.any_instance.stubs(:call_llm_api).raises(
      StandardError, "API temporarily unavailable"
    )
  end

  # Perform an LLM job synchronously for testing
  def perform_llm_job(**params)
    default_params = {
      template: "Test {{message}}",
      model: "gpt-4",
      context: { message: "Hello" },
      format: "text"
    }

    LLMJob.perform_now(default_params.merge(params))
  end
end

# Include in test cases
class ActiveSupport::TestCase
  include LLMTestHelper
end

class ActionDispatch::IntegrationTest
  include LLMTestHelper
end