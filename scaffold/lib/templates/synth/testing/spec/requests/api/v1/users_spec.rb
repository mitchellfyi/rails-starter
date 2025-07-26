# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::V1::Users', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace) }

  describe 'GET /api/v1/users/:id' do
    context 'when authenticated' do
      before do
        get "/api/v1/users/#{user.id}", headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns user data in JSON:API format' do
        expect_json_api_resource(
          type: 'users',
          attributes: { email: user.email }
        )
      end

      it 'includes user relationships' do
        expect(json_data['relationships']).to be_present
        expect(json_data['relationships']['workspaces']).to be_present
      end
    end

    context 'when not authenticated' do
      before do
        get "/api/v1/users/#{user.id}", headers: json_api_headers
      end

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error details' do
        expect_json_api_error(status: :unauthorized, detail: 'Authentication required')
      end
    end

    context 'when user not found' do
      before do
        get '/api/v1/users/99999', headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns error details' do
        expect_json_api_error(status: :not_found, detail: 'User not found')
      end
    end
  end

  describe 'PATCH /api/v1/users/:id' do
    let(:update_params) do
      {
        data: {
          type: 'users',
          id: user.id.to_s,
          attributes: {
            first_name: 'Updated',
            last_name: 'Name'
          }
        }
      }
    end

    context 'when authenticated as the user' do
      before do
        patch "/api/v1/users/#{user.id}",
              params: update_params.to_json,
              headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'updates user attributes' do
        user.reload
        expect(user.first_name).to eq('Updated') if user.respond_to?(:first_name)
        expect(user.last_name).to eq('Name') if user.respond_to?(:last_name)
      end

      it 'returns updated user data' do
        expect_json_api_resource(type: 'users')
        if user.respond_to?(:first_name)
          expect(json_data['attributes']['first_name']).to eq('Updated')
        end
      end
    end

    context 'when trying to update another user' do
      let(:other_user) { create(:user) }

      before do
        patch "/api/v1/users/#{other_user.id}",
              params: update_params.to_json,
              headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns error details' do
        expect_json_api_error(status: :forbidden, detail: 'Access denied')
      end
    end

    context 'with invalid data' do
      let(:invalid_params) do
        {
          data: {
            type: 'users',
            id: user.id.to_s,
            attributes: {
              email: 'invalid-email'
            }
          }
        }
      end

      before do
        patch "/api/v1/users/#{user.id}",
              params: invalid_params.to_json,
              headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        expect_json_api_error(status: :unprocessable_entity, detail: 'Email is invalid')
      end
    end
  end

  describe 'DELETE /api/v1/users/:id' do
    context 'when authenticated as the user' do
      before do
        delete "/api/v1/users/#{user.id}", headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns no content status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes the user' do
        expect(User.find_by(id: user.id)).to be_nil
      end
    end

    context 'when trying to delete another user' do
      let(:other_user) { create(:user) }

      before do
        delete "/api/v1/users/#{other_user.id}", headers: json_api_headers.merge(auth_headers(user))
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end