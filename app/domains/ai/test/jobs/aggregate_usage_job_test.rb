# frozen_string_literal: true

require 'test_helper'

class AggregateUsageJobTest < ActiveSupport::TestCase
  def setup
    @workspace = Workspace.create!(name: 'Test Workspace')
    @date = Date.current - 1.day
  end

  test 'should aggregate usage for a specific date' do
    # Create some LLMOutput records for the date
    LLMOutput.create!(
      template_name: 'test',
      model_name: 'gpt-4',
      format: 'text',
      status: 'completed',
      job_id: 'test-1',
      workspace: @workspace,
      input_tokens: 100,
      output_tokens: 50,
      actual_cost: 0.05,
      created_at: @date.beginning_of_day + 1.hour
    )

    LLMOutput.create!(
      template_name: 'test',
      model_name: 'gpt-4',
      format: 'text',
      status: 'completed',
      job_id: 'test-2',
      workspace: @workspace,
      input_tokens: 200,
      output_tokens: 100,
      estimated_cost: 0.10,
      created_at: @date.beginning_of_day + 2.hours
    )

    # Run the job
    job = AggregateUsageJob.new
    job.perform(@date)

    # Check that usage was aggregated
    usage = LlmUsage.find_by(workspace: @workspace, date: @date)
    assert_not_nil usage
    assert_equal 'openai', usage.provider
    assert_equal 'gpt-4', usage.model
    assert_equal 300, usage.prompt_tokens
    assert_equal 150, usage.completion_tokens
    assert_equal 0.15, usage.cost
    assert_equal 2, usage.request_count
  end

  test 'should handle job failure gracefully' do
    # Mock LlmUsage.aggregate_for_date to raise an error
    LlmUsage.stub :aggregate_for_date, -> (_) { raise StandardError, 'Test error' } do
      job = AggregateUsageJob.new
      
      assert_raises StandardError do
        job.perform(@date)
      end
    end
  end

  test 'should default to yesterday if no date provided' do
    yesterday = Date.current - 1.day
    
    # Mock aggregate_for_date to capture the date argument
    called_with_date = nil
    LlmUsage.stub :aggregate_for_date, ->(date) { called_with_date = date; 0 } do
      job = AggregateUsageJob.new
      job.perform
    end
    
    assert_equal yesterday, called_with_date
  end

  test 'should cleanup old usage data' do
    # Create old usage records
    old_date = Date.current - 3.years
    LlmUsage.create!(
      workspace: @workspace,
      provider: 'openai',
      model: 'gpt-4',
      date: old_date,
      cost: 1.0
    )

    recent_date = Date.current - 1.month
    LlmUsage.create!(
      workspace: @workspace,
      provider: 'openai',
      model: 'gpt-4',
      date: recent_date,
      cost: 1.0
    )

    job = AggregateUsageJob.new
    job.perform(@date)

    # Old record should be deleted, recent one should remain
    assert_nil LlmUsage.find_by(date: old_date)
    assert_not_nil LlmUsage.find_by(date: recent_date)
  end
end