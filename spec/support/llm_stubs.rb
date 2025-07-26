# frozen_string_literal: true

# spec/support/llm_stubs.rb

module LlmStubs
  def stub_openai_chat_completion
    # Stub OpenAI API calls
    allow_any_instance_of(OpenAI::Client).to receive(:chat) do |client, parameters: {}
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "This is a mocked LLM response for: #{parameters[:messages].last[:content]}"
            }
          }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 20,
          "total_tokens" => 30
        }
      }
    end
  end

  def stub_anthropic_completion
    # Stub Anthropic API calls
    # Example: allow_any_instance_of(Anthropic::Client).to receive(:completions)
  end
end

RSpec.configure do |config|
  config.include LlmStubs
end
