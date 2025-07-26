# frozen_string_literal: true

require 'test_helper'

class PromptExecutionTest < ActiveSupport::TestCase
  def setup
    @template = PromptTemplate.create!(
      name: 'Test Template',
      prompt_body: 'Hello {{name}}!',
      output_format: 'text'
    )
    @execution = PromptExecution.create!(
      prompt_template: @template,
      input_context: { name: 'John' },
      rendered_prompt: 'Hello John!',
      status: 'pending'
    )
  end

  test 'should be valid with required attributes' do
    execution = PromptExecution.new(
      prompt_template: @template,
      input_context: { test: 'value' },
      rendered_prompt: 'Test prompt',
      status: 'pending'
    )
    assert execution.valid?
  end

  test 'should require prompt_template' do
    execution = PromptExecution.new(
      input_context: { test: 'value' },
      rendered_prompt: 'Test',
      status: 'pending'
    )
    assert_not execution.valid?
    assert_includes execution.errors[:prompt_template], "must exist"
  end

  test 'should require input_context' do
    execution = PromptExecution.new(
      prompt_template: @template,
      rendered_prompt: 'Test',
      status: 'pending'
    )
    assert_not execution.valid?
    assert_includes execution.errors[:input_context], "can't be blank"
  end

  test 'should require valid status' do
    execution = PromptExecution.new(
      prompt_template: @template,
      input_context: { test: 'value' },
      rendered_prompt: 'Test',
      status: 'invalid_status'
    )
    assert_not execution.valid?
    assert_includes execution.errors[:status], 'is not included in the list'
  end

  test 'should identify successful executions' do
    @execution.update!(status: 'completed')
    assert @execution.success?
    assert_not @execution.failed?
  end

  test 'should identify failed executions' do
    @execution.update!(status: 'failed')
    assert @execution.failed?
    assert_not @execution.success?
  end

  test 'should identify preview executions' do
    @execution.update!(status: 'preview')
    assert @execution.preview?
  end

  test 'should calculate duration when both timestamps exist' do
    start_time = Time.current
    end_time = start_time + 5.seconds
    
    @execution.update!(started_at: start_time, completed_at: end_time)
    assert_equal 5.0, @execution.duration
  end

  test 'should return nil duration when timestamps missing' do
    assert_nil @execution.duration
  end

  test 'should scope successful executions' do
    successful = PromptExecution.create!(
      prompt_template: @template,
      input_context: { test: 'value' },
      rendered_prompt: 'Test',
      status: 'completed'
    )
    
    results = PromptExecution.successful
    assert_includes results, successful
    assert_not_includes results, @execution
  end

  test 'should scope failed executions' do
    failed = PromptExecution.create!(
      prompt_template: @template,
      input_context: { test: 'value' },
      rendered_prompt: 'Test',
      status: 'failed'
    )
    
    results = PromptExecution.failed
    assert_includes results, failed
    assert_not_includes results, @execution
  end

  test 'should scope preview executions' do
    preview = PromptExecution.create!(
      prompt_template: @template,
      input_context: { test: 'value' },
      rendered_prompt: 'Test',
      status: 'preview'
    )
    
    results = PromptExecution.preview
    assert_includes results, preview
    assert_not_includes results, @execution
  end

  test 'should order by created_at desc for recent scope' do
    older = PromptExecution.create!(
      prompt_template: @template,
      input_context: { test: 'old' },
      rendered_prompt: 'Old',
      status: 'completed',
      created_at: 1.hour.ago
    )
    
    newer = PromptExecution.create!(
      prompt_template: @template,
      input_context: { test: 'new' },
      rendered_prompt: 'New',
      status: 'completed'
    )

    recent = PromptExecution.recent
    assert_equal newer, recent.first
    assert_equal older, recent.second
  end
end