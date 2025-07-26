# frozen_string_literal: true

require 'test_helper'

class LLMOutputTest < ActiveSupport::TestCase
  setup do
    @user = users(:one) # Assumes fixtures exist
    @llm_output = LLMOutput.create!(
      template_name: "Test template",
      model_name: "gpt-4",
      context: { name: "Alice" },
      format: "text",
      status: "completed",
      job_id: "test-job-123",
      prompt: "Hello Alice",
      raw_response: "Hello! Nice to meet you Alice.",
      parsed_output: "Hello! Nice to meet you Alice.",
      user_id: @user.id
    )
  end

  test "should be valid with required attributes" do
    assert @llm_output.valid?
  end

  test "should require template_name" do
    @llm_output.template_name = nil
    assert_not @llm_output.valid?
    assert_includes @llm_output.errors[:template_name], "can't be blank"
  end

  test "should require model_name" do
    @llm_output.model_name = nil
    assert_not @llm_output.valid?
    assert_includes @llm_output.errors[:model_name], "can't be blank"
  end

  test "should require format" do
    @llm_output.format = nil
    assert_not @llm_output.valid?
    assert_includes @llm_output.errors[:format], "can't be blank"
  end

  test "should validate format inclusion" do
    @llm_output.format = "invalid_format"
    assert_not @llm_output.valid?
    assert_includes @llm_output.errors[:format], "is not included in the list"

    %w[text json markdown html].each do |valid_format|
      @llm_output.format = valid_format
      assert @llm_output.valid?, "#{valid_format} should be a valid format"
    end
  end

  test "should validate status inclusion" do
    @llm_output.status = "invalid_status"
    assert_not @llm_output.valid?
    assert_includes @llm_output.errors[:status], "is not included in the list"

    %w[pending processing completed failed].each do |valid_status|
      @llm_output.status = valid_status
      assert @llm_output.valid?, "#{valid_status} should be a valid status"
    end
  end

  test "should have feedback enum" do
    assert_equal 0, @llm_output.feedback
    assert @llm_output.none?

    @llm_output.thumbs_up!
    assert @llm_output.thumbs_up?
    assert_equal 1, @llm_output.feedback

    @llm_output.thumbs_down!
    assert @llm_output.thumbs_down?
    assert_equal 2, @llm_output.feedback
  end

  test "should have scopes" do
    # Create additional records for testing scopes
    completed_output = LLMOutput.create!(
      template_name: "Another template",
      model_name: "gpt-3.5",
      format: "json",
      status: "completed",
      job_id: "job-456"
    )

    failed_output = LLMOutput.create!(
      template_name: "Failed template",
      model_name: "gpt-4",
      format: "text",
      status: "failed",
      job_id: "job-789"
    )

    assert_includes LLMOutput.completed, @llm_output
    assert_includes LLMOutput.completed, completed_output
    assert_not_includes LLMOutput.completed, failed_output

    assert_includes LLMOutput.failed, failed_output
    assert_not_includes LLMOutput.failed, @llm_output

    assert_includes LLMOutput.by_template("Test template"), @llm_output
    assert_not_includes LLMOutput.by_template("Test template"), completed_output

    assert_includes LLMOutput.by_model("gpt-4"), @llm_output
    assert_not_includes LLMOutput.by_model("gpt-4"), completed_output
  end

  test "re_run! should queue new job with same parameters" do
    assert_enqueued_with(
      job: LLMJob,
      args: [{
        template: @llm_output.template_name,
        model: @llm_output.model_name,
        context: @llm_output.context,
        format: @llm_output.format,
        user_id: @llm_output.user_id,
        agent_id: @llm_output.agent_id
      }]
    ) do
      @llm_output.re_run!
    end
  end

  test "regenerate! should queue new job with modified parameters" do
    new_context = { name: "Bob" }
    new_model = "gpt-3.5"

    assert_enqueued_with(
      job: LLMJob,
      args: [{
        template: @llm_output.template_name,
        model: new_model,
        context: new_context,
        format: @llm_output.format,
        user_id: @llm_output.user_id,
        agent_id: @llm_output.agent_id
      }]
    ) do
      @llm_output.regenerate!(new_context: new_context, new_model: new_model)
    end
  end

  test "set_feedback! should update feedback and log" do
    Rails.logger.expects(:info).with("LLM output feedback received", anything)

    assert_nil @llm_output.feedback_at
    @llm_output.set_feedback!('thumbs_up')
    
    assert @llm_output.thumbs_up?
    assert_not_nil @llm_output.feedback_at
  end

  test "status check methods" do
    @llm_output.status = 'completed'
    assert @llm_output.success?
    assert_not @llm_output.failed?
    assert_not @llm_output.pending?
    assert_not @llm_output.processing?

    @llm_output.status = 'failed'
    assert_not @llm_output.success?
    assert @llm_output.failed?
    assert_not @llm_output.pending?
    assert_not @llm_output.processing?

    @llm_output.status = 'pending'
    assert_not @llm_output.success?
    assert_not @llm_output.failed?
    assert @llm_output.pending?
    assert_not @llm_output.processing?

    @llm_output.status = 'processing'
    assert_not @llm_output.success?
    assert_not @llm_output.failed?
    assert_not @llm_output.pending?
    assert @llm_output.processing?
  end

  test "formatted_output should format based on format type" do
    # JSON format
    json_output = LLMOutput.create!(
      template_name: "JSON template",
      model_name: "gpt-4",
      format: "json",
      status: "completed",
      job_id: "json-job",
      parsed_output: '{"key": "value"}'
    )
    assert_includes json_output.formatted_output, "key"
    assert_includes json_output.formatted_output, "value"

    # Text format
    assert_equal @llm_output.parsed_output, @llm_output.formatted_output
  end

  test "estimated_token_count should estimate tokens" do
    @llm_output.raw_response = "a" * 100 # 100 characters
    assert_equal 25, @llm_output.estimated_token_count # 100/4 = 25

    @llm_output.raw_response = nil
    assert_equal 0, @llm_output.estimated_token_count
  end

  test "should allow optional user and agent" do
    output = LLMOutput.create!(
      template_name: "Template",
      model_name: "gpt-4",
      format: "text",
      status: "pending",
      job_id: "job-no-user"
    )
    assert output.valid?
    assert_nil output.user
    assert_nil output.agent
  end
end