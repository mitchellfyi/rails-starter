# frozen_string_literal: true

require 'test_helper'

class LLMJobSystemTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # Assumes fixtures exist
    sign_in @user
  end

  test "complete LLM job workflow" do
    # 1. Create a job via API
    job_params = {
      template: "Hello {{name}}, tell me about {{topic}}",
      model: "gpt-4",
      context: { name: "Alice", topic: "Ruby on Rails" },
      format: "text"
    }

    # Mock successful API response
    stub_llm_api_success

    # Create the job
    assert_difference 'LLMOutput.count', 1 do
      post api_v1_llm_jobs_url,
           params: job_params,
           headers: { 'Accept' => 'application/json' }
    end

    assert_response :created
    response_json = JSON.parse(response.body)
    output_id = response_json['output_id']

    # 2. Execute the job (simulating Sidekiq processing)
    assert_performed_jobs 1 do
      perform_enqueued_jobs
    end

    # 3. Verify the output was created correctly
    output = LLMOutput.find(output_id)
    assert_equal 'completed', output.status
    assert_equal 'Hello Alice, tell me about Ruby on Rails', output.prompt
    assert_not_nil output.raw_response
    assert_not_nil output.parsed_output
    assert_equal @user.id, output.user_id

    # 4. Test viewing the output
    get llm_output_url(output)
    assert_response :success

    # 5. Test providing feedback
    post feedback_llm_output_url(output), params: { feedback_type: 'thumbs_up' }
    assert_response :redirect

    output.reload
    assert output.thumbs_up?
    assert_not_nil output.feedback_at

    # 6. Test re-running the job
    assert_difference 'LLMOutput.count', 1 do
      assert_enqueued_with(job: LLMJob) do
        post re_run_llm_output_url(output)
      end
    end

    # 7. Test regenerating with new context
    new_context = { name: "Bob", topic: "Python" }
    assert_enqueued_with(job: LLMJob) do
      post regenerate_llm_output_url(output), params: { context: new_context }
    end

    # 8. Test listing outputs
    get llm_outputs_url
    assert_response :success
    assert_select 'body', text: /#{output.template_name}/
  end

  test "job failure and retry workflow" do
    job_params = {
      template: "This will fail",
      model: "gpt-4",
      context: {},
      format: "text"
    }

    # Mock API failure
    stub_llm_api_failure

    # Create the job
    post api_v1_llm_jobs_url,
         params: job_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :created
    response_json = JSON.parse(response.body)
    output_id = response_json['output_id']

    # Attempt to process the job (will fail)
    assert_raises(StandardError) do
      perform_enqueued_jobs
    end

    # The job should be retried according to Sidekiq configuration
    # In a real scenario, this would be handled by Sidekiq's retry mechanism
  end

  test "feedback workflow with different types" do
    output = create_test_llm_output(user: @user)

    # Test thumbs up
    post feedback_llm_output_url(output), 
         params: { feedback_type: 'thumbs_up' },
         headers: { 'Accept' => 'application/json' }

    assert_response :success
    response_json = JSON.parse(response.body)
    assert_equal 'success', response_json['status']
    assert_equal 'thumbs_up', response_json['feedback']

    output.reload
    assert output.thumbs_up?

    # Test changing to thumbs down
    post feedback_llm_output_url(output), 
         params: { feedback_type: 'thumbs_down' },
         headers: { 'Accept' => 'application/json' }

    assert_response :success
    output.reload
    assert output.thumbs_down?

    # Test clearing feedback
    post feedback_llm_output_url(output), 
         params: { feedback_type: 'none' },
         headers: { 'Accept' => 'application/json' }

    assert_response :success
    output.reload
    assert output.none?
  end

  test "access control for different users" do
    other_user = users(:two)
    other_user_output = create_test_llm_output(user: other_user)

    # Current user should not be able to access other user's output actions
    post feedback_llm_output_url(other_user_output), 
         params: { feedback_type: 'thumbs_up' }

    assert_redirected_to root_path
    assert_equal 'Access denied', flash[:alert]

    # But should be able to view it publicly
    get llm_output_url(other_user_output)
    assert_response :success
  end

  test "different output formats" do
    %w[text json markdown html].each do |format|
      job_params = {
        template: "Generate content in {{format}} format",
        model: "gpt-4",
        context: { format: format },
        format: format
      }

      stub_llm_api_success(format: format)

      post api_v1_llm_jobs_url,
           params: job_params,
           headers: { 'Accept' => 'application/json' }

      assert_response :created, "Failed to create job for #{format} format"

      # Process the job
      perform_enqueued_jobs

      output = LLMOutput.last
      assert_equal format, output.format
      assert_not_nil output.formatted_output
    end
  end

  test "job queuing without authentication should fail" do
    sign_out @user

    post api_v1_llm_jobs_url,
         params: { template: "test", model: "gpt-4" },
         headers: { 'Accept' => 'application/json' }

    assert_response :unauthorized
  end

  test "empty context handling" do
    job_params = {
      template: "Generate a random fact",
      model: "gpt-4",
      format: "text"
    }

    stub_llm_api_success

    post api_v1_llm_jobs_url,
         params: job_params,
         headers: { 'Accept' => 'application/json' }

    assert_response :created

    perform_enqueued_jobs

    output = LLMOutput.last
    assert_equal({}, output.context)
    assert_equal "Generate a random fact", output.prompt
  end
end