# frozen_string_literal: true

require 'test_helper'

class LLMOutputsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # Assumes fixtures exist
    @other_user = users(:two)
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
    sign_in @user # Assumes Devise test helpers
  end

  test "should get index" do
    get llm_outputs_url
    assert_response :success
  end

  test "should show llm_output" do
    get llm_output_url(@llm_output)
    assert_response :success
  end

  test "should show llm_output without authentication for public access" do
    sign_out @user
    get llm_output_url(@llm_output)
    assert_response :success
  end

  test "should not allow access to other users' outputs" do
    sign_out @user
    sign_in @other_user
    
    get llm_outputs_url
    assert_response :success
    # Should not include other user's outputs
  end

  test "should set thumbs up feedback" do
    post feedback_llm_output_url(@llm_output), params: { feedback_type: 'thumbs_up' }
    assert_redirected_to @llm_output
    
    @llm_output.reload
    assert @llm_output.thumbs_up?
    assert_not_nil @llm_output.feedback_at
  end

  test "should set thumbs down feedback" do
    post feedback_llm_output_url(@llm_output), params: { feedback_type: 'thumbs_down' }
    assert_redirected_to @llm_output
    
    @llm_output.reload
    assert @llm_output.thumbs_down?
  end

  test "should clear feedback" do
    @llm_output.update!(feedback: 'thumbs_up')
    
    post feedback_llm_output_url(@llm_output), params: { feedback_type: 'none' }
    assert_redirected_to @llm_output
    
    @llm_output.reload
    assert @llm_output.none?
  end

  test "should reject invalid feedback type" do
    post feedback_llm_output_url(@llm_output), params: { feedback_type: 'invalid' }
    assert_response :bad_request
  end

  test "should handle feedback with JSON response" do
    post feedback_llm_output_url(@llm_output), 
         params: { feedback_type: 'thumbs_up' },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    response_json = JSON.parse(response.body)
    assert_equal 'success', response_json['status']
    assert_equal 'thumbs_up', response_json['feedback']
  end

  test "should re-run job" do
    assert_enqueued_with(job: LLMJob) do
      post re_run_llm_output_url(@llm_output)
    end
    
    assert_redirected_to @llm_output
    follow_redirect!
    assert_select '.notice', text: /Job queued for re-run/
  end

  test "should regenerate job" do
    new_context = { name: "Bob" }
    
    assert_enqueued_with(job: LLMJob) do
      post regenerate_llm_output_url(@llm_output), 
           params: { context: new_context }
    end
    
    assert_redirected_to @llm_output
  end

  test "should regenerate job with JSON response" do
    post regenerate_llm_output_url(@llm_output),
         params: { context: { name: "Bob" } },
         headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    response_json = JSON.parse(response.body)
    assert_equal 'success', response_json['status']
    assert_includes response_json['message'], 'regeneration'
  end

  test "should require authentication for feedback" do
    sign_out @user
    post feedback_llm_output_url(@llm_output), params: { feedback_type: 'thumbs_up' }
    assert_response :redirect # Should redirect to login
  end

  test "should require authentication for re-run" do
    sign_out @user
    post re_run_llm_output_url(@llm_output)
    assert_response :redirect # Should redirect to login
  end

  test "should require authentication for regenerate" do
    sign_out @user
    post regenerate_llm_output_url(@llm_output)
    assert_response :redirect # Should redirect to login
  end

  test "should deny access to other users' outputs for actions" do
    other_user_output = LLMOutput.create!(
      template_name: "Other template",
      model_name: "gpt-4",
      format: "text", 
      status: "completed",
      job_id: "other-job",
      user_id: @other_user.id
    )

    post feedback_llm_output_url(other_user_output), params: { feedback_type: 'thumbs_up' }
    assert_redirected_to root_path
    assert_equal 'Access denied', flash[:alert]
  end
end