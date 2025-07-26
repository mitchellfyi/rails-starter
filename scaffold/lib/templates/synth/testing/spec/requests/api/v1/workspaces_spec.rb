# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V1::Workspaces', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

  describe 'GET /api/v1/workspaces' do
    let!(:other_workspace) { create(:workspace) }

    context 'when authenticated' do
      before do
        get '/api/v1/workspaces', headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns only user workspaces' do
        expect(json_data).to be_an(Array)
        expect(json_data.length).to eq(1)
        expect(json_data.first['attributes']['name']).to eq(workspace.name)
      end

      it 'includes pagination meta data' do
        expect(json_response['meta']).to be_present
        expect(json_response['meta']['total']).to eq(1)
      end
    end

    context 'when not authenticated' do
      before do
        get '/api/v1/workspaces', headers: json_api_headers
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/workspaces/:id' do
    context 'when user is a member' do
      before do
        get "/api/v1/workspaces/#{workspace.id}", headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns workspace data' do
        expect_json_api_resource(
          type: 'workspaces',
          attributes: {
            name: workspace.name,
            slug: workspace.slug
          }
        )
      end

      it 'includes workspace relationships' do
        expect(json_data['relationships']).to be_present
        expect(json_data['relationships']['memberships']).to be_present
      end
    end

    context 'when user is not a member' do
      let(:other_user) { create(:user) }

      before do
        get "/api/v1/workspaces/#{workspace.id}", headers: json_api_headers.merge(auth_headers(other_user))
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/workspaces' do
    let(:workspace_params) do
      {
        data: {
          type: 'workspaces',
          attributes: {
            name: 'New Workspace',
            slug: 'new-workspace'
          }
        }
      }
    end

    context 'when authenticated' do
      before do
        post '/api/v1/workspaces',
             params: workspace_params.to_json,
             headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns created status' do
        expect(response).to have_http_status(:created)
      end

      it 'creates a new workspace' do
        expect(Workspace.count).to eq(2) # including existing workspace
        new_workspace = Workspace.find_by(name: 'New Workspace')
        expect(new_workspace).to be_present
      end

      it 'creates owner membership for user' do
        new_workspace = Workspace.find_by(name: 'New Workspace')
        owner_membership = new_workspace.memberships.find_by(user: user)
        expect(owner_membership.role).to eq('owner')
      end

      it 'returns workspace data' do
        expect_json_api_resource(
          type: 'workspaces',
          attributes: { name: 'New Workspace' }
        )
      end
    end

    context 'with invalid data' do
      let(:invalid_params) do
        {
          data: {
            type: 'workspaces',
            attributes: {
              name: ''
            }
          }
        }
      end

      before do
        post '/api/v1/workspaces',
             params: invalid_params.to_json,
             headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        expect_json_api_error(status: :unprocessable_entity, detail: "Name can't be blank")
      end
    end
  end

  describe 'PATCH /api/v1/workspaces/:id' do
    let(:update_params) do
      {
        data: {
          type: 'workspaces',
          id: workspace.id.to_s,
          attributes: {
            name: 'Updated Workspace Name'
          }
        }
      }
    end

    context 'when user is owner' do
      before do
        patch "/api/v1/workspaces/#{workspace.id}",
              params: update_params.to_json,
              headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'updates workspace name' do
        workspace.reload
        expect(workspace.name).to eq('Updated Workspace Name')
      end
    end

    context 'when user is not owner' do
      let(:member_user) { create(:user) }
      let!(:member_membership) { create(:membership, user: member_user, workspace: workspace, role: 'member') }

      before do
        patch "/api/v1/workspaces/#{workspace.id}",
              params: update_params.to_json,
              headers: json_api_headers.merge(auth_headers(member_user))
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/workspaces/:id' do
    context 'when user is owner' do
      before do
        delete "/api/v1/workspaces/#{workspace.id}", headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes the workspace' do
        expect(Workspace.find_by(id: workspace.id)).to be_nil
      end
    end

    context 'when user is not owner' do
      let(:member_user) { create(:user) }
      let!(:member_membership) { create(:membership, user: member_user, workspace: workspace, role: 'member') }

      before do
        delete "/api/v1/workspaces/#{workspace.id}", headers: json_api_headers.merge(auth_headers(member_user))
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end