# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Prompt System', type: :system do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

  before do
    sign_in user
    driven_by(:rack_test)
  end

  describe 'prompt template management' do
    scenario 'user creates a new prompt template' do
      visit workspace_ai_prompt_templates_path(workspace)
      click_link 'New Template'
      
      fill_in 'Name', with: 'greeting_template'
      fill_in 'Content', with: 'Hello {{name}}, welcome to {{workspace}}!'
      select 'Text', from: 'Output format'
      fill_in 'Tags', with: 'greeting, welcome'
      
      click_button 'Create Template'
      
      expect(page).to have_content('Template created successfully')
      expect(page).to have_content('greeting_template')
    end

    scenario 'user previews prompt template with context' do
      template = create(:prompt_template, 
        workspace: workspace,
        content: 'Hello {{name}}, your role is {{role}}!'
      )
      
      visit workspace_ai_prompt_template_path(workspace, template)
      click_link 'Preview'
      
      fill_in 'name', with: 'John'
      fill_in 'role', with: 'Developer'
      click_button 'Preview'
      
      expect(page).to have_content('Hello John, your role is Developer!')
    end

    scenario 'user versions a prompt template' do
      template = create(:prompt_template, workspace: workspace, version: '1.0.0')
      
      visit workspace_ai_prompt_template_path(workspace, template)
      click_link 'Create Version'
      
      fill_in 'Content', with: 'Updated template content'
      fill_in 'Version', with: '2.0.0'
      click_button 'Create Version'
      
      expect(page).to have_content('Version 2.0.0 created')
      expect(page).to have_content('Updated template content')
    end

    scenario 'user compares template versions' do
      template_v1 = create(:prompt_template, 
        workspace: workspace,
        name: 'test_template',
        version: '1.0.0',
        content: 'Original content'
      )
      template_v2 = create(:prompt_template, 
        workspace: workspace,
        name: 'test_template', 
        version: '2.0.0',
        content: 'Updated content'
      )
      
      visit workspace_ai_prompt_template_path(workspace, template_v2)
      click_link 'Compare Versions'
      
      expect(page).to have_content('Version Comparison')
      expect(page).to have_content('Original content')
      expect(page).to have_content('Updated content')
    end
  end

  describe 'LLM job execution' do
    let!(:template) { create(:prompt_template, workspace: workspace) }

    scenario 'user runs a prompt job' do
      visit workspace_ai_prompt_template_path(workspace, template)
      click_button 'Run Prompt'
      
      select 'GPT-3.5 Turbo', from: 'Model'
      fill_in 'name', with: 'Alice'
      click_button 'Execute'
      
      expect(page).to have_content('Job started')
      expect(page).to have_content('Processing')
    end

    scenario 'user views job results' do
      job = create(:llm_job, :with_output, 
        workspace: workspace, 
        user: user, 
        prompt_template: template,
        status: 'completed'
      )
      
      visit workspace_ai_llm_job_path(workspace, job)
      
      expect(page).to have_content('Completed')
      expect(page).to have_content(job.llm_output.content)
      expect(page).to have_content('Input tokens')
      expect(page).to have_content('Output tokens')
    end

    scenario 'user provides feedback on results' do
      job = create(:llm_job, :with_output, workspace: workspace, user: user)
      
      visit workspace_ai_llm_job_path(workspace, job)
      
      click_button 'Thumbs Up'
      
      expect(page).to have_content('Feedback recorded')
      job.llm_output.reload
      expect(job.llm_output.feedback_score).to eq(1)
    end

    scenario 'user regenerates failed job' do
      job = create(:llm_job, :failed, 
        workspace: workspace, 
        user: user,
        prompt_template: template
      )
      
      visit workspace_ai_llm_job_path(workspace, job)
      click_button 'Retry'
      
      expect(page).to have_content('Job retried')
      job.reload
      expect(job.status).to eq('pending')
    end
  end

  describe 'job history and management' do
    let!(:template) { create(:prompt_template, workspace: workspace) }
    let!(:jobs) { create_list(:llm_job, 5, workspace: workspace, user: user, prompt_template: template) }

    scenario 'user views job history' do
      visit workspace_ai_llm_jobs_path(workspace)
      
      expect(page).to have_content('AI Jobs')
      jobs.each do |job|
        expect(page).to have_content(job.prompt_template.name)
        expect(page).to have_content(job.status.titleize)
      end
    end

    scenario 'user filters jobs by status' do
      completed_job = create(:llm_job, status: 'completed', workspace: workspace, user: user)
      failed_job = create(:llm_job, :failed, workspace: workspace, user: user)
      
      visit workspace_ai_llm_jobs_path(workspace)
      select 'Completed', from: 'Status'
      click_button 'Filter'
      
      expect(page).to have_content(completed_job.id)
      expect(page).not_to have_content(failed_job.id)
    end

    scenario 'user bulk retries failed jobs' do
      failed_jobs = create_list(:llm_job, 3, :failed, workspace: workspace, user: user)
      
      visit workspace_ai_llm_jobs_path(workspace)
      
      failed_jobs.each do |job|
        check "job_#{job.id}"
      end
      
      click_button 'Retry Selected'
      
      expect(page).to have_content('3 jobs retried')
    end
  end

  describe 'AI analytics and insights' do
    let!(:template) { create(:prompt_template, workspace: workspace) }

    scenario 'user views AI usage analytics' do
      create_list(:llm_job, 10, :with_output, workspace: workspace, prompt_template: template)
      
      visit workspace_ai_analytics_path(workspace)
      
      expect(page).to have_content('AI Usage Analytics')
      expect(page).to have_content('Total Jobs')
      expect(page).to have_content('Success Rate')
      expect(page).to have_content('Token Usage')
      expect(page).to have_content('Cost Estimate')
    end

    scenario 'user views template performance' do
      high_rated_jobs = create_list(:llm_job, 3, :with_output, 
        workspace: workspace, 
        prompt_template: template
      )
      high_rated_jobs.each { |job| job.llm_output.update(feedback_score: 1) }
      
      visit workspace_ai_prompt_template_path(workspace, template)
      click_link 'Analytics'
      
      expect(page).to have_content('Template Performance')
      expect(page).to have_content('Positive Feedback')
      expect(page).to have_content('Average Rating')
    end
  end

  describe 'collaborative features' do
    let(:other_user) { create(:user) }
    let!(:other_membership) { create(:membership, user: other_user, workspace: workspace, role: 'member') }
    let!(:template) { create(:prompt_template, workspace: workspace) }

    scenario 'team members can view shared templates' do
      sign_out user
      sign_in other_user
      
      visit workspace_ai_prompt_templates_path(workspace)
      
      expect(page).to have_content(template.name)
    end

    scenario 'team members can run shared templates' do
      sign_out user
      sign_in other_user
      
      visit workspace_ai_prompt_template_path(workspace, template)
      
      expect(page).to have_button('Run Prompt')
    end

    scenario 'only admins can edit templates' do
      sign_out user
      sign_in other_user
      
      visit workspace_ai_prompt_template_path(workspace, template)
      
      expect(page).not_to have_link('Edit')
      expect(page).not_to have_link('Delete')
    end
  end

  describe 'prompt template validation' do
    scenario 'user sees validation errors for invalid templates' do
      visit workspace_ai_prompt_templates_path(workspace)
      click_link 'New Template'
      
      fill_in 'Content', with: 'Invalid template with {{unclosed_variable'
      click_button 'Create Template'
      
      expect(page).to have_content('Template syntax is invalid')
      expect(page).to have_content('Unclosed variable')
    end

    scenario 'user gets help with template syntax' do
      visit new_workspace_ai_prompt_template_path(workspace)
      click_link 'Template Help'
      
      expect(page).to have_content('Template Syntax Guide')
      expect(page).to have_content('Variables: {{variable_name}}')
      expect(page).to have_content('Examples')
    end
  end

  describe 'export and import' do
    let!(:templates) { create_list(:prompt_template, 3, workspace: workspace) }

    scenario 'user exports prompt templates' do
      visit workspace_ai_prompt_templates_path(workspace)
      click_button 'Export Templates'
      
      expect(page.response_headers['Content-Type']).to include('application/json')
    end

    scenario 'user imports prompt templates' do
      visit workspace_ai_prompt_templates_path(workspace)
      click_link 'Import Templates'
      
      attach_file 'File', Rails.root.join('spec/fixtures/templates.json')
      click_button 'Import'
      
      expect(page).to have_content('Templates imported successfully')
    end
  end
end