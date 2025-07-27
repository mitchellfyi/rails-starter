# frozen_string_literal: true

require 'test_helper'

class AiUsageEstimatorServiceTest < ActiveSupport::TestCase
  def setup
    @service = AiUsageEstimatorService.new
  end

  test "estimate_single returns proper structure" do
    template = "Hello {{name}}, how are you today?"
    context = { name: "John" }
    
    result = @service.estimate_single(
      template: template,
      model: "gpt-3.5-turbo",
      context: context,
      format: "text"
    )
    
    assert_includes result.keys, :prompt
    assert_includes result.keys, :input_tokens
    assert_includes result.keys, :output_tokens
    assert_includes result.keys, :total_tokens
    assert_includes result.keys, :cost_breakdown
    assert_includes result.keys, :total_cost
    assert_includes result.keys, :model
    assert_includes result.keys, :provider
    
    assert_equal "Hello John, how are you today?", result[:prompt]
    assert_equal "gpt-3.5-turbo", result[:model]
    assert_equal "openai", result[:provider]
    assert result[:input_tokens] > 0
    assert result[:output_tokens] > 0
    assert result[:total_cost] > 0
  end

  test "estimate_single interpolates template correctly" do
    template = "Process {{data}} in {{style}} format"
    context = { data: "user feedback", style: "JSON" }
    
    result = @service.estimate_single(
      template: template,
      model: "gpt-4",
      context: context
    )
    
    assert_equal "Process user feedback in JSON format", result[:prompt]
  end

  test "estimate_single handles different output formats" do
    template = "Test prompt"
    
    %w[text json markdown html].each do |format|
      result = @service.estimate_single(
        template: template,
        model: "gpt-3.5-turbo",
        format: format
      )
      
      assert result[:output_tokens] > 0
      # Different formats should have different estimated output tokens
      # JSON tends to be shorter, markdown longer
    end
  end

  test "estimate_batch returns proper structure" do
    template = "Summarize: {{content}}"
    inputs = [
      { content: "First piece of content" },
      { content: "Second piece of content" },
      { content: "Third piece of content" }
    ]
    
    result = @service.estimate_batch(
      inputs,
      template: template,
      model: "gpt-3.5-turbo"
    )
    
    assert_includes result.keys, :estimates
    assert_includes result.keys, :summary
    
    # Check estimates
    assert_equal 3, result[:estimates].length
    result[:estimates].each_with_index do |estimate, index|
      assert estimate[:success]
      assert_equal index, estimate[:index]
      assert estimate[:input_tokens] > 0
      assert estimate[:total_cost] > 0
    end
    
    # Check summary
    summary = result[:summary]
    assert_equal 3, summary[:total_inputs]
    assert_equal 3, summary[:successful_estimates]
    assert_equal 0, summary[:failed_estimates]
    assert summary[:total_cost] > 0
    assert summary[:total_tokens] > 0
  end

  test "estimate_batch handles errors gracefully" do
    template = "Process {{missing_var}}"  # Template with variable not in context
    inputs = [
      { content: "Valid content" },
      { other_field: "Invalid context" }  # Missing the variable the template needs
    ]
    
    result = @service.estimate_batch(
      inputs,
      template: template,
      model: "gpt-3.5-turbo"
    )
    
    # Should still process successfully (interpolation just leaves {{missing_var}} as-is)
    assert_equal 2, result[:estimates].length
    assert result[:estimates].all? { |e| e[:success] }
  end

  test "available_models returns models" do
    models = @service.available_models
    assert models.is_a?(Array)
    assert models.include?("gpt-3.5-turbo")
    assert models.include?("gpt-4")
  end

  test "model_pricing returns pricing structure" do
    pricing = @service.model_pricing("gpt-3.5-turbo")
    
    assert_includes pricing.keys, :input
    assert_includes pricing.keys, :output
    assert pricing[:input] > 0
    assert pricing[:output] > 0
  end

  test "get_provider_for_model returns correct provider" do
    service = @service
    
    assert_equal "openai", service.send(:get_provider_for_model, "gpt-4")
    assert_equal "openai", service.send(:get_provider_for_model, "gpt-3.5-turbo")
    assert_equal "anthropic", service.send(:get_provider_for_model, "claude-3-opus")
    assert_equal "cohere", service.send(:get_provider_for_model, "command")
  end

  test "estimate_tokens calculates reasonable token count" do
    service = @service
    
    # Short text
    short_text = "Hello world"
    short_tokens = service.send(:estimate_tokens, short_text)
    assert short_tokens > 0
    assert short_tokens < 10
    
    # Long text
    long_text = "This is a much longer piece of text that should result in significantly more tokens than the short text above. It contains multiple sentences and should demonstrate the token estimation working correctly."
    long_tokens = service.send(:estimate_tokens, long_text)
    assert long_tokens > short_tokens
  end

  test "estimate_output_tokens varies by format and model" do
    service = @service
    
    # JSON should generally be shorter than markdown
    json_tokens = service.send(:estimate_output_tokens, "json", "gpt-4")
    markdown_tokens = service.send(:estimate_output_tokens, "markdown", "gpt-4")
    
    assert json_tokens > 0
    assert markdown_tokens > 0
    assert markdown_tokens > json_tokens
  end

  test "calculate_cost calculates correct costs" do
    service = @service
    
    input_tokens = 1000
    output_tokens = 500
    
    cost_breakdown = service.send(:calculate_cost, "gpt-3.5-turbo", input_tokens, output_tokens)
    
    assert_includes cost_breakdown.keys, :input_cost
    assert_includes cost_breakdown.keys, :output_cost
    assert_includes cost_breakdown.keys, :total_cost
    assert_includes cost_breakdown.keys, :pricing_per_1k
    
    # Total should equal input + output
    expected_total = cost_breakdown[:input_cost] + cost_breakdown[:output_cost]
    assert_in_delta expected_total, cost_breakdown[:total_cost], 0.000001
  end

  test "service works with workspace and ai_credential" do
    # Test that service accepts workspace and ai_credential parameters
    # In a real test, you'd create actual records
    service = AiUsageEstimatorService.new(workspace: nil, ai_credential: nil)
    
    result = service.estimate_single(
      template: "Test {{variable}}",
      model: "gpt-3.5-turbo",
      context: { variable: "value" }
    )
    
    assert result[:total_cost] > 0
  end
end