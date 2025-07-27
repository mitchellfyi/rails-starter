#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for AI Usage Estimator functionality
# This script demonstrates the core functionality without requiring a full Rails setup

require 'json'
require 'csv'
require 'tempfile'

# Simplified version of the AiUsageEstimatorService for demo purposes
class AiUsageEstimatorDemo
  MODEL_PRICING = {
    'openai' => {
      'gpt-4' => { input: 0.03, output: 0.06 },
      'gpt-4-turbo' => { input: 0.01, output: 0.03 },
      'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 }
    },
    'anthropic' => {
      'claude-3-opus' => { input: 0.015, output: 0.075 },
      'claude-3-sonnet' => { input: 0.003, output: 0.015 }
    }
  }.freeze

  def estimate_single(template:, model:, context: {}, format: 'text')
    prompt = interpolate_template(template, context)
    input_tokens = estimate_tokens(prompt)
    output_tokens = estimate_output_tokens(format, model)
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

  def estimate_batch(inputs, template:, model:, format: 'text')
    estimates = inputs.map.with_index do |context, index|
      result = estimate_single(template: template, model: model, context: context, format: format)
      result.merge(index: index, success: true)
    end

    successful_estimates = estimates.select { |e| e[:success] }
    total_input_tokens = successful_estimates.sum { |e| e[:input_tokens] }
    total_output_tokens = successful_estimates.sum { |e| e[:output_tokens] }
    total_cost = successful_estimates.sum { |e| e[:total_cost] }

    {
      estimates: estimates,
      summary: {
        total_inputs: inputs.length,
        successful_estimates: successful_estimates.length,
        total_input_tokens: total_input_tokens,
        total_output_tokens: total_output_tokens,
        total_tokens: total_input_tokens + total_output_tokens,
        total_cost: total_cost,
        model: model
      }
    }
  end

  private

  def interpolate_template(template, context)
    result = template.dup
    context.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    result
  end

  def estimate_tokens(text)
    (text.length / 4.0).ceil
  end

  def estimate_output_tokens(format, model)
    case format
    when 'json'
      case model
      when /gpt-4/ then 400
      when /gpt-3.5/ then 250
      else 300
      end
    when 'markdown'
      case model
      when /gpt-4/ then 800
      when /gpt-3.5/ then 500
      else 600
      end
    else
      case model
      when /gpt-4/ then 500
      when /gpt-3.5/ then 300
      else 400
      end
    end
  end

  def calculate_cost(model, input_tokens, output_tokens)
    pricing = model_pricing(model)
    input_cost = (input_tokens / 1000.0) * pricing[:input]
    output_cost = (output_tokens / 1000.0) * pricing[:output]
    
    {
      input_cost: input_cost.round(6),
      output_cost: output_cost.round(6),
      total_cost: (input_cost + output_cost).round(6),
      pricing_per_1k: pricing
    }
  end

  def model_pricing(model)
    provider = get_provider_for_model(model)
    MODEL_PRICING.dig(provider, model) || { input: 0.002, output: 0.004 }
  end

  def get_provider_for_model(model)
    MODEL_PRICING.each do |provider, models|
      return provider if models.key?(model)
    end
    'openai'
  end
end

# Demo functions
def print_separator(title)
  puts "\n" + "=" * 60
  puts title.center(60)
  puts "=" * 60
end

def format_currency(amount)
  "$#{sprintf('%.6f', amount)}"
end

def demo_single_estimation
  print_separator("SINGLE ESTIMATION DEMO")
  
  estimator = AiUsageEstimatorDemo.new
  
  template = "Please summarize the following content in {{style}} style:\n\n{{content}}"
  context = {
    content: "Artificial Intelligence (AI) is transforming industries across the globe. From healthcare to finance, AI technologies are enabling unprecedented automation, insights, and efficiency gains. However, challenges remain in areas such as ethics, bias, and regulatory frameworks.",
    style: "bullet points"
  }
  
  puts "Template:"
  puts template
  puts "\nContext:"
  puts JSON.pretty_generate(context)
  
  result = estimator.estimate_single(
    template: template,
    model: "gpt-4",
    context: context,
    format: "markdown"
  )
  
  puts "\n--- ESTIMATION RESULTS ---"
  puts "Generated Prompt:"
  puts result[:prompt]
  puts "\nToken Analysis:"
  puts "  Input Tokens: #{result[:input_tokens].to_s.rjust(10)}"
  puts "  Output Tokens: #{result[:output_tokens].to_s.rjust(9)}"
  puts "  Total Tokens: #{result[:total_tokens].to_s.rjust(10)}"
  puts "\nCost Analysis:"
  puts "  Input Cost: #{format_currency(result[:cost_breakdown][:input_cost]).rjust(12)}"
  puts "  Output Cost: #{format_currency(result[:cost_breakdown][:output_cost]).rjust(11)}"
  puts "  Total Cost: #{format_currency(result[:total_cost]).rjust(11)}"
  puts "\nModel: #{result[:model]} (#{result[:provider]})"
end

def demo_batch_estimation
  print_separator("BATCH ESTIMATION DEMO")
  
  estimator = AiUsageEstimatorDemo.new
  
  template = "Translate '{{text}}' from {{from_lang}} to {{to_lang}}"
  inputs = [
    { text: "Hello, how are you?", from_lang: "English", to_lang: "Spanish" },
    { text: "Good morning", from_lang: "English", to_lang: "French" },
    { text: "Thank you very much", from_lang: "English", to_lang: "German" },
    { text: "Have a nice day", from_lang: "English", to_lang: "Italian" },
    { text: "See you later", from_lang: "English", to_lang: "Portuguese" }
  ]
  
  puts "Template:"
  puts template
  puts "\nBatch Inputs (#{inputs.length} items):"
  inputs.each_with_index do |input, index|
    puts "  #{index + 1}. #{input[:text]} (#{input[:from_lang]} → #{input[:to_lang]})"
  end
  
  result = estimator.estimate_batch(
    inputs,
    template: template,
    model: "gpt-3.5-turbo",
    format: "text"
  )
  
  puts "\n--- BATCH ESTIMATION RESULTS ---"
  summary = result[:summary]
  puts "Summary:"
  puts "  Total Inputs: #{summary[:total_inputs].to_s.rjust(13)}"
  puts "  Successful: #{summary[:successful_estimates].to_s.rjust(15)}"
  puts "  Total Tokens: #{summary[:total_tokens].to_s.rjust(12)}"
  puts "  Total Cost: #{format_currency(summary[:total_cost]).rjust(14)}"
  puts "  Avg Cost/Input: #{format_currency(summary[:total_cost] / summary[:total_inputs]).rjust(10)}"
  
  puts "\nIndividual Estimates:"
  result[:estimates].each do |estimate|
    puts "  #{estimate[:index] + 1}. Tokens: #{estimate[:total_tokens].to_s.rjust(4)} | Cost: #{format_currency(estimate[:total_cost])}"
  end
end

def demo_cost_comparison
  print_separator("MODEL COST COMPARISON")
  
  estimator = AiUsageEstimatorDemo.new
  
  template = "Write a detailed technical blog post about {{topic}} targeting {{audience}}. Include code examples and best practices."
  context = { topic: "GraphQL API design", audience: "senior developers" }
  
  models = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo", "claude-3-sonnet", "claude-3-opus"]
  
  puts "Prompt Template:"
  puts template
  puts "\nContext: #{context.inspect}"
  puts "\nCost Comparison Across Models:"
  puts "-" * 70
  printf("%-20s %10s %12s %12s\n", "Model", "Tokens", "Cost", "Provider")
  puts "-" * 70
  
  models.each do |model|
    begin
      result = estimator.estimate_single(
        template: template,
        model: model,
        context: context,
        format: "markdown"
      )
      
      printf("%-20s %10d %12s %12s\n",
        model,
        result[:total_tokens],
        format_currency(result[:total_cost]),
        result[:provider]
      )
    rescue => e
      printf("%-20s %10s %12s %12s\n", model, "ERROR", "N/A", "N/A")
    end
  end
end

def demo_file_processing
  print_separator("FILE PROCESSING DEMO")
  
  # Create sample CSV data
  csv_data = [
    ["name", "product", "sentiment"],
    ["Alice", "Widget Pro", "positive"],
    ["Bob", "SuperTool", "negative"],
    ["Carol", "MegaApp", "neutral"],
    ["David", "UltraDevice", "positive"]
  ]
  
  # Create temporary CSV file
  csv_file = Tempfile.new(['demo', '.csv'])
  CSV.open(csv_file.path, 'w') do |writer|
    csv_data.each { |row| writer << row }
  end
  
  puts "Sample CSV file created:"
  File.read(csv_file.path).each_line.with_index do |line, index|
    puts "  #{index + 1}. #{line.chomp}"
  end
  
  # Parse CSV and estimate
  inputs = CSV.parse(File.read(csv_file.path), headers: true).map(&:to_h)
  
  estimator = AiUsageEstimatorDemo.new
  template = "Analyze customer feedback: '{{name}}' reviewed '{{product}}' with {{sentiment}} sentiment. Provide insights."
  
  result = estimator.estimate_batch(
    inputs,
    template: template,
    model: "gpt-4",
    format: "json"
  )
  
  puts "\n--- FILE PROCESSING RESULTS ---"
  puts "Processed #{inputs.length} rows from CSV"
  puts "Total estimated cost: #{format_currency(result[:summary][:total_cost])}"
  puts "Average cost per row: #{format_currency(result[:summary][:total_cost] / inputs.length)}"
  
  csv_file.close
  csv_file.unlink
end

# Run demonstrations
if __FILE__ == $0
  puts "AI Usage Estimator Demo"
  puts "Rails SaaS Starter Template - AI Domain"
  puts "=" * 60
  
  demo_single_estimation
  demo_batch_estimation
  demo_cost_comparison
  demo_file_processing
  
  print_separator("DEMO COMPLETE")
  puts "The AI Usage Estimator provides comprehensive cost estimation"
  puts "for both single prompts and batch operations, supporting"
  puts "multiple AI providers and models with detailed breakdowns."
  puts ""
  puts "Key Features Demonstrated:"
  puts "✓ Single prompt estimation with context interpolation"
  puts "✓ Batch processing with cost aggregation" 
  puts "✓ Multi-model cost comparison"
  puts "✓ CSV file processing capabilities"
  puts "✓ Detailed token and cost breakdowns"
  puts ""
  puts "Access the web interface at: /ai_usage_estimator"
  puts "API Documentation: /app/domains/ai/AI_USAGE_ESTIMATOR.md"
end