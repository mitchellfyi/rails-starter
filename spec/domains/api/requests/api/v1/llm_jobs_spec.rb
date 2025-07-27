# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/v1/llm_jobs', type: :request do
  path '/api/v1/llm_jobs' do
    post('create LLM job') do
      tags 'LLM Jobs'
      description 'Queue an LLM job for processing with specified template and context'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :llm_job, in: :body, schema: {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              type: { type: :string, enum: ['llm-job'] },
              attributes: {
                type: :object,
                properties: {
                  template: { 
                    type: :string, 
                    description: 'Name of the prompt template to use',
                    example: 'email_response'
                  },
                  model: { 
                    type: :string, 
                    description: 'LLM model to use',
                    example: 'gpt-4',
                    enum: ['gpt-4', 'gpt-3.5-turbo', 'claude-3', 'claude-2']
                  },
                  context: { 
                    type: :object,
                    description: 'Context variables for the prompt template',
                    example: {
                      customer_name: 'John Doe',
                      issue: 'Billing inquiry'
                    }
                  },
                  format: { 
                    type: :string, 
                    description: 'Output format',
                    enum: ['text', 'json', 'markdown', 'html'],
                    default: 'text'
                  }
                },
                required: [:template, :model]
              }
            },
            required: [:type, :attributes]
          }
        },
        required: [:data]
      }

      response(201, 'LLM job created successfully') do
        schema '$ref' => '#/components/schemas/JsonApiResource'
        
        let(:user) { create(:user) }
        let(:llm_job) do
          {
            data: {
              type: 'llm-job',
              attributes: {
                template: 'test_template',
                model: 'gpt-4',
                context: { test: 'value' },
                format: 'text'
              }
            }
          }
        end

        before { sign_in user }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['type']).to eq('llm-output')
          expect(data['data']['attributes']).to include(
            'template_name' => 'test_template',
            'model_name' => 'gpt-4',
            'status' => 'pending'
          )
        end
      end

      response(400, 'Bad request - invalid parameters') do
        schema '$ref' => '#/components/schemas/JsonApiError'
        
        let(:user) { create(:user) }
        let(:llm_job) do
          {
            data: {
              type: 'llm-job',
              attributes: {
                template: 'test_template',
                model: 'gpt-4',
                format: 'invalid_format'
              }
            }
          }
        end

        before { sign_in user }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_present
          expect(data['errors'].first['status']).to eq('400')
          expect(data['errors'].first['title']).to eq('Invalid format')
        end
      end

      response(400, 'Bad request - missing required parameter') do
        schema '$ref' => '#/components/schemas/JsonApiError'
        
        let(:user) { create(:user) }
        let(:llm_job) do
          {
            data: {
              type: 'llm-job',
              attributes: {
                template: 'test_template'
                # Missing required model parameter
              }
            }
          }
        end

        before { sign_in user }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_present
          expect(data['errors'].first['status']).to eq('400')
          expect(data['errors'].first['title']).to eq('Missing required parameter')
        end
      end

      response(401, 'Unauthorized - authentication required') do
        schema '$ref' => '#/components/schemas/JsonApiError'
        
        let(:llm_job) do
          {
            data: {
              type: 'llm-job',
              attributes: {
                template: 'test_template',
                model: 'gpt-4'
              }
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_present
          expect(data['errors'].first['status']).to eq('401')
        end
      end

      response(500, 'Internal server error') do
        schema '$ref' => '#/components/schemas/JsonApiError'
        
        let(:user) { create(:user) }
        let(:llm_job) do
          {
            data: {
              type: 'llm-job',
              attributes: {
                template: 'test_template',
                model: 'gpt-4'
              }
            }
          }
        end

        before do
          sign_in user
          # Simulate an internal error
          allow(LLMJob).to receive(:perform_later).and_raise(StandardError, 'Internal error')
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_present
          expect(data['errors'].first['status']).to eq('500')
          expect(data['errors'].first['title']).to eq('Failed to queue job')
        end
      end
    end
  end
end