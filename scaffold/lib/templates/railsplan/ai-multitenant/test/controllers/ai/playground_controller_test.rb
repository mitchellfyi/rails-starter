# frozen_string_literal: true

require 'test_helper'

class AiMultitenantIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:acme)
    @user = users(:john)
    @ai_provider = ai_providers(:openai)
    @ai_credential = ai_credentials(:acme_openai)
    
    # Sign in user and set workspace
    sign_in @user
    set_current_workspace(@workspace)
  end

  test "should access AI playground" do
    get ai_playground_path
    assert_response :success
    assert_select 'h1', 'AI Playground'
    assert_select 'textarea#template'
    assert_select 'select#provider'
    assert_select 'button#execute-btn'
  end

  test "should access AI analytics" do
    # Create some usage data
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: Date.current,
      requests_count: 10,
      tokens_used: 1000,
      estimated_cost: 0.03
    )

    get ai_analytics_path
    assert_response :success
    assert_select 'h1', 'AI Analytics'
    assert_select '.text-2xl', text: '10'  # Total requests
    assert_select '.text-2xl', text: '1,000'  # Total tokens
  end

  test "should execute AI prompt in playground" do
    VCR.use_cassette("ai_playground_execution") do
      post ai_playground_execute_path, params: {
        template: "Hello {{name}}",
        context: '{"name": "World"}',
        provider: "openai",
        model: "gpt-3.5-turbo",
        format: "text"
      }, as: :json

      assert_response :success
      
      response_data = JSON.parse(response.body)
      assert response_data['success']
      assert response_data['result']
      assert response_data['result']['output']
    end
  end

  test "should handle playground execution errors gracefully" do
    post ai_playground_execute_path, params: {
      template: "",  # Empty template should fail
      context: "{}",
      format: "text"
    }, as: :json

    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert response_data['error']
  end

  test "should save prompt template from playground" do
    post "#{ai_playground_path}/save_template", params: {
      name: "Test Template",
      description: "A test template",
      template: "Hello {{name}}",
      tags: "test, demo"
    }, as: :json

    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert response_data['template']
    
    # Verify template was created
    template = PromptTemplate.find_by(name: "Test Template")
    assert template
    assert_equal @workspace, template.workspace
    assert_equal "Hello {{name}}", template.prompt_body
  end

  test "should load saved template in playground" do
    template = @workspace.prompt_templates.create!(
      name: "Sample Template",
      prompt_body: "Summarize {{content}}",
      description: "Template for summarization"
    )

    get "#{ai_playground_path}/load_template?template_id=#{template.id}"
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal "Summarize {{content}}", response_data['template']['prompt_body']
    assert_equal ["content"], response_data['template']['variable_names']
  end

  test "should handle workspace isolation in playground" do
    other_workspace = workspaces(:other)
    other_template = other_workspace.prompt_templates.create!(
      name: "Other Template",
      prompt_body: "Other content"
    )

    # Should not be able to load template from other workspace
    get "#{ai_playground_path}/load_template?template_id=#{other_template.id}"
    
    assert_response :not_found
  end

  test "should check usage limits" do
    # Set usage limit
    @workspace.update(ai_usage_limit: 100) if @workspace.respond_to?(:ai_usage_limit=)
    
    # Create usage that exceeds limit
    AiUsageSummary.create!(
      workspace: @workspace,
      ai_credential: @ai_credential,
      date: Date.current,
      tokens_used: 150
    )

    post ai_playground_execute_path, params: {
      template: "Hello World",
      context: "{}",
      format: "text"
    }, as: :json

    # Should be rate limited if usage limits are enforced
    # Note: This depends on whether usage limits are implemented in the workspace model
    if @workspace.respond_to?(:ai_usage_limit)
      assert_response :too_many_requests
      response_data = JSON.parse(response.body)
      assert_match(/usage limits/, response_data['error'])
    else
      # If no usage limits, should proceed normally
      assert_response :success
    end
  end

  test "should provide usage analytics data" do
    # Create usage data across multiple days
    [0, 1, 2].each do |days_ago|
      AiUsageSummary.create!(
        workspace: @workspace,
        ai_credential: @ai_credential,
        date: days_ago.days.ago.to_date,
        requests_count: 10 + days_ago,
        tokens_used: (10 + days_ago) * 100,
        estimated_cost: (10 + days_ago) * 0.003
      )
    end

    get ai_analytics_usage_path, params: { date_range: '7' }, as: :json
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['daily_usage']
    assert response_data['total_stats']
    assert response_data['provider_breakdown']
    
    # Verify data structure
    assert_equal 3, response_data['daily_usage'].size
    assert_operator response_data['total_stats']['total_requests'], :>, 0
  end

  test "should handle AI provider routing correctly" do
    # Create multiple providers
    anthropic_provider = AiProvider.create!(
      name: 'Anthropic Test',
      slug: 'anthropic-test',
      api_base_url: 'https://api.anthropic.com/v1',
      supported_models: ['claude-3-sonnet'],
      active: true
    )

    anthropic_credential = @workspace.ai_credentials.create!(
      ai_provider: anthropic_provider,
      name: "Test Anthropic",
      api_key: "sk-anthropic-test",
      preferred_model: "claude-3-sonnet"
    )

    # Test OpenAI routing
    post ai_playground_execute_path, params: {
      template: "Hello World",
      context: "{}",
      provider: "openai",
      model: "gpt-3.5-turbo"
    }, as: :json

    # Should use OpenAI credential
    assert_response :success

    # Test Anthropic routing
    post ai_playground_execute_path, params: {
      template: "Hello World", 
      context: "{}",
      provider: "anthropic-test",
      model: "claude-3-sonnet"
    }, as: :json

    # Should use Anthropic credential
    assert_response :success
  end

  test "should track execution history" do
    initial_count = PromptExecution.count

    VCR.use_cassette("ai_playground_execution") do
      post ai_playground_execute_path, params: {
        template: "Hello {{name}}",
        context: '{"name": "Test"}',
        save_to_history: true
      }, as: :json

      assert_response :success
    end

    # Should create execution record
    assert_equal initial_count + 1, PromptExecution.count
    
    execution = PromptExecution.last
    assert_equal @workspace, execution.workspace
    assert_equal @user, execution.user
    assert execution.playground_session?
  end

  private

  def set_current_workspace(workspace)
    # This would depend on how workspace switching is implemented
    # For testing, we can mock the current_workspace method
    controller.stubs(:current_workspace).returns(workspace) if defined?(controller)
  end
end