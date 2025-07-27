# frozen_string_literal: true

class AiUsageEstimatorService
  # Standard pricing per 1000 tokens for different models (in USD)
  # These should be configurable per workspace/provider in a real implementation
  MODEL_PRICING = {
    'openai' => {
      'gpt-4' => { input: 0.03, output: 0.06 },
      'gpt-4-turbo' => { input: 0.01, output: 0.03 },
      'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 },
      'gpt-3.5-turbo-16k' => { input: 0.003, output: 0.004 }
    },
    'anthropic' => {
      'claude-3-opus' => { input: 0.015, output: 0.075 },
      'claude-3-sonnet' => { input: 0.003, output: 0.015 },
      'claude-3-haiku' => { input: 0.00025, output: 0.00125 }
    },
    'cohere' => {
      'command' => { input: 0.0015, output: 0.002 },
      'command-light' => { input: 0.0003, output: 0.0006 }
    }
  }.freeze

  attr_reader :workspace, :ai_credential

  def initialize(workspace: nil, ai_credential: nil)
    @workspace = workspace
    @ai_credential = ai_credential
  end

  # Estimate usage for a single prompt
  def estimate_single(template:, model:, context: {}, format: 'text')
    # Interpolate the template with context to get the actual prompt
    prompt = interpolate_template(template, context)
    
    # Estimate input tokens
    input_tokens = estimate_tokens(prompt)
    
    # Estimate output tokens based on format and typical response length
    output_tokens = estimate_output_tokens(format, model)
    
    # Calculate costs
    cost_breakdown = calculate_cost(model, input_tokens, output_tokens)
    
    {
      prompt: prompt,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens,
      cost_breakdown: cost_breakdown,
      total_cost: cost_breakdown[:total_cost],
      model: model,
      provider: get_provider_for_model(model)
    }
  end

  # Estimate usage for multiple inputs (batch processing)
  def estimate_batch(inputs, template:, model:, format: 'text')
    estimates = inputs.map.with_index do |context, index|
      begin
        result = estimate_single(
          template: template,
          model: model,
          context: context,
          format: format
        )
        result.merge(index: index, success: true)
      rescue => e
        {
          index: index,
          success: false,
          error: e.message,
          context: context
        }
      end
    end

    # Calculate totals
    successful_estimates = estimates.select { |e| e[:success] }
    total_input_tokens = successful_estimates.sum { |e| e[:input_tokens] || 0 }
    total_output_tokens = successful_estimates.sum { |e| e[:output_tokens] || 0 }
    total_cost = successful_estimates.sum { |e| e[:total_cost] || 0 }

    {
      estimates: estimates,
      summary: {
        total_inputs: inputs.length,
        successful_estimates: successful_estimates.length,
        failed_estimates: estimates.count { |e| !e[:success] },
        total_input_tokens: total_input_tokens,
        total_output_tokens: total_output_tokens,
        total_tokens: total_input_tokens + total_output_tokens,
        total_cost: total_cost,
        average_cost_per_input: successful_estimates.length > 0 ? total_cost / successful_estimates.length : 0,
        model: model,
        provider: get_provider_for_model(model)
      }
    }
  end

  # Get available models for a workspace based on AI credentials
  def available_models
    if ai_credential
      provider_slug = ai_credential.ai_provider.slug
      MODEL_PRICING[provider_slug]&.keys || []
    else
      # Return all models if no specific credential
      MODEL_PRICING.values.flat_map(&:keys).uniq
    end
  end

  # Get pricing information for a model
  def model_pricing(model)
    provider = get_provider_for_model(model)
    MODEL_PRICING.dig(provider, model) || { input: 0.002, output: 0.004 } # fallback pricing
  end

  private

  def interpolate_template(template, context)
    # Simple variable interpolation - replace {{variable}} with context values
    result = template.dup
    context.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end

  def estimate_tokens(text)
    # Rough estimation: ~4 characters per token for English text
    # In a real implementation, use tiktoken or similar library
    (text.length / 4.0).ceil
  end

  def estimate_output_tokens(format, model)
    # Estimate output tokens based on format and model capabilities
    case format
    when 'json'
      # JSON responses tend to be more structured and concise
      case model
      when /gpt-4/
        400  # GPT-4 can generate more detailed JSON
      when /gpt-3.5/
        250  # GPT-3.5 typically shorter responses
      when /claude/
        350  # Claude balanced responses
      else
        300  # Default
      end
    when 'markdown'
      # Markdown responses tend to be longer with formatting
      case model
      when /gpt-4/
        800
      when /gpt-3.5/
        500
      when /claude/
        700
      else
        600
      end
    when 'html'
      # HTML responses include markup overhead
      case model
      when /gpt-4/
        600
      when /gpt-3.5/
        400
      when /claude/
        550
      else
        500
      end
    else # text
      # Plain text responses
      case model
      when /gpt-4/
        500
      when /gpt-3.5/
        300
      when /claude/
        450
      else
        400
      end
    end
  end

  def calculate_cost(model, input_tokens, output_tokens)
    pricing = model_pricing(model)
    
    input_cost = (input_tokens / 1000.0) * pricing[:input]
    output_cost = (output_tokens / 1000.0) * pricing[:output]
    total_cost = input_cost + output_cost

    {
      input_cost: input_cost.round(6),
      output_cost: output_cost.round(6),
      total_cost: total_cost.round(6),
      pricing_per_1k: pricing
    }
  end

  def get_provider_for_model(model)
    MODEL_PRICING.each do |provider, models|
      return provider if models.key?(model)
    end
    
    # Fallback: try to infer from model name
    case model.downcase
    when /gpt|openai/
      'openai'
    when /claude|anthropic/
      'anthropic'
    when /command|cohere/
      'cohere'
    else
      'openai' # default fallback
    end
  end
end