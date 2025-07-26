# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MCP Context System', type: :system do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

  before do
    sign_in user
    driven_by(:rack_test)
  end

  describe 'MCP fetcher management' do
    scenario 'user creates HTTP fetcher' do
      visit workspace_ai_mcp_fetchers_path(workspace)
      click_link 'New Fetcher'
      
      fill_in 'Name', with: 'github_user_info'
      select 'HTTP', from: 'Type'
      fill_in 'URL', with: 'https://api.github.com/users/{{username}}'
      select 'GET', from: 'Method'
      fill_in 'Headers', with: '{"Authorization": "token {{github_token}}"}'
      
      click_button 'Create Fetcher'
      
      expect(page).to have_content('Fetcher created successfully')
      expect(page).to have_content('github_user_info')
    end

    scenario 'user creates database fetcher' do
      visit workspace_ai_mcp_fetchers_path(workspace)
      click_link 'New Fetcher'
      
      fill_in 'Name', with: 'user_stats'
      select 'Database', from: 'Type'
      fill_in 'Query', with: 'SELECT count(*) as total FROM users WHERE workspace_id = ?'
      fill_in 'Parameters', with: '["{{workspace_id}}"]'
      
      click_button 'Create Fetcher'
      
      expect(page).to have_content('Fetcher created successfully')
      expect(page).to have_content('user_stats')
    end

    scenario 'user tests fetcher configuration' do
      fetcher = create(:mcp_fetcher, workspace: workspace, name: 'test_fetcher')
      
      visit workspace_ai_mcp_fetcher_path(workspace, fetcher)
      click_button 'Test Fetcher'
      
      fill_in 'username', with: 'testuser'
      fill_in 'github_token', with: 'test_token'
      click_button 'Run Test'
      
      expect(page).to have_content('Test Results')
      expect(page).to have_content('testuser')
    end
  end

  describe 'context composition' do
    let!(:github_fetcher) { create(:mcp_fetcher, workspace: workspace, name: 'github_user') }
    let!(:db_fetcher) { create(:mcp_fetcher, :database_fetcher, workspace: workspace, name: 'user_count') }
    let!(:template) { create(:prompt_template, 
      workspace: workspace,
      content: 'User {{github.name}} has {{user_count.total}} team members.'
    )}

    scenario 'user configures context for prompt template' do
      visit workspace_ai_prompt_template_path(workspace, template)
      click_link 'Configure Context'
      
      select 'github_user', from: 'github'
      select 'user_count', from: 'user_count'
      
      click_button 'Save Context Configuration'
      
      expect(page).to have_content('Context configuration saved')
    end

    scenario 'user previews prompt with MCP context' do
      visit workspace_ai_prompt_template_path(workspace, template)
      click_link 'Preview with Context'
      
      fill_in 'username', with: 'testuser'
      fill_in 'workspace_id', with: workspace.id
      click_button 'Preview'
      
      expect(page).to have_content('Test User has')
      expect(page).to have_content('team members')
    end
  end

  describe 'context debugging' do
    let!(:fetcher) { create(:mcp_fetcher, workspace: workspace) }

    scenario 'user views context fetch logs' do
      job = create(:llm_job, workspace: workspace, user: user)
      
      visit workspace_ai_llm_job_path(workspace, job)
      click_link 'Context Debug'
      
      expect(page).to have_content('Context Fetch Log')
      expect(page).to have_content('Fetcher Results')
      expect(page).to have_content('Execution Time')
    end

    scenario 'user retries failed context fetch' do
      job = create(:llm_job, workspace: workspace, user: user, status: 'failed')
      
      visit workspace_ai_llm_job_path(workspace, job)
      click_link 'Context Debug'
      click_button 'Retry Context Fetch'
      
      expect(page).to have_content('Context fetch retried')
    end
  end

  describe 'fetcher templates and sharing' do
    scenario 'user creates fetcher from template' do
      visit workspace_ai_mcp_fetchers_path(workspace)
      click_link 'Browse Templates'
      
      within('.github-api-template') do
        click_button 'Use Template'
      end
      
      fill_in 'Name', with: 'my_github_fetcher'
      click_button 'Create from Template'
      
      expect(page).to have_content('Fetcher created from template')
      expect(page).to have_content('my_github_fetcher')
    end

    scenario 'user shares fetcher configuration' do
      fetcher = create(:mcp_fetcher, workspace: workspace)
      
      visit workspace_ai_mcp_fetcher_path(workspace, fetcher)
      click_button 'Share Configuration'
      
      expect(page).to have_content('Shareable Link')
      expect(page).to have_field('share_url')
    end
  end

  describe 'performance monitoring' do
    let!(:fetcher) { create(:mcp_fetcher, workspace: workspace) }

    scenario 'user views fetcher performance metrics' do
      visit workspace_ai_mcp_fetcher_path(workspace, fetcher)
      click_link 'Performance'
      
      expect(page).to have_content('Performance Metrics')
      expect(page).to have_content('Average Response Time')
      expect(page).to have_content('Success Rate')
      expect(page).to have_content('Usage Count')
    end

    scenario 'user sets up fetcher caching' do
      visit edit_workspace_ai_mcp_fetcher_path(workspace, fetcher)
      
      check 'Enable caching'
      fill_in 'Cache duration (minutes)', with: '60'
      click_button 'Update Fetcher'
      
      expect(page).to have_content('Caching enabled')
    end
  end

  describe 'security and permissions' do
    scenario 'user manages fetcher secrets' do
      fetcher = create(:mcp_fetcher, workspace: workspace)
      
      visit workspace_ai_mcp_fetcher_path(workspace, fetcher)
      click_link 'Manage Secrets'
      
      fill_in 'github_token', with: 'secret_token_value'
      fill_in 'api_key', with: 'secret_api_key'
      click_button 'Save Secrets'
      
      expect(page).to have_content('Secrets saved securely')
      expect(page).not_to have_content('secret_token_value')
    end

    scenario 'member cannot edit fetchers' do
      other_user = create(:user)
      create(:membership, user: other_user, workspace: workspace, role: 'member')
      fetcher = create(:mcp_fetcher, workspace: workspace)
      
      sign_out user
      sign_in other_user
      
      visit workspace_ai_mcp_fetcher_path(workspace, fetcher)
      
      expect(page).not_to have_link('Edit')
      expect(page).not_to have_link('Delete')
    end
  end

  describe 'batch operations' do
    let!(:fetchers) { create_list(:mcp_fetcher, 3, workspace: workspace) }

    scenario 'user bulk tests multiple fetchers' do
      visit workspace_ai_mcp_fetchers_path(workspace)
      
      fetchers.each do |fetcher|
        check "fetcher_#{fetcher.id}"
      end
      
      click_button 'Test Selected'
      
      expect(page).to have_content('Testing 3 fetchers')
      expect(page).to have_content('Test Results')
    end

    scenario 'user exports fetcher configurations' do
      visit workspace_ai_mcp_fetchers_path(workspace)
      click_button 'Export All'
      
      expect(page.response_headers['Content-Type']).to include('application/json')
    end
  end

  describe 'integration with prompt system' do
    let!(:fetcher) { create(:mcp_fetcher, workspace: workspace, name: 'user_data') }
    let!(:template) { create(:prompt_template, 
      workspace: workspace,
      content: 'Generate report for {{user_data.name}} with {{user_data.stats}}'
    )}

    scenario 'user runs prompt with MCP context integration' do
      visit workspace_ai_prompt_template_path(workspace, template)
      click_button 'Run with Context'
      
      select 'GPT-3.5 Turbo', from: 'Model'
      fill_in 'user_id', with: '123'
      click_button 'Execute'
      
      expect(page).to have_content('Job started with context')
      expect(page).to have_content('Fetching context data')
    end

    scenario 'user views context data in job results' do
      job = create(:llm_job, :with_output, 
        workspace: workspace, 
        user: user,
        prompt_template: template,
        context: { user_data: { name: 'John', stats: 'Active' } }
      )
      
      visit workspace_ai_llm_job_path(workspace, job)
      click_link 'View Context'
      
      expect(page).to have_content('Context Data Used')
      expect(page).to have_content('user_data')
      expect(page).to have_content('John')
      expect(page).to have_content('Active')
    end
  end
end