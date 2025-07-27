# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestWithHyphensController, type: :controller do
  let(:user) { create(:user) }
  let(:test-with-hyphens_item) { create(:test-with-hyphens_item, user: user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @test-with-hyphens_items' do
      test-with-hyphens_item # Create the item
      get :index
      expect(assigns(:test-with-hyphens_items)).to include(test-with-hyphens_item)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: test-with-hyphens_item.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { id: test-with-hyphens_item.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        { name: 'Test Item', description: 'Test Description' }
      end

      it 'creates a new TestWithHyphensItem' do
        expect {
          post :create, params: { test-with-hyphens_item: valid_attributes }
        }.to change(TestWithHyphensItem, :count).by(1)
      end

      it 'redirects to the created test-with-hyphens_item' do
        post :create, params: { test-with-hyphens_item: valid_attributes }
        expect(response).to redirect_to(TestWithHyphensItem.last)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Test Description' }
      end

      it 'does not create a new TestWithHyphensItem' do
        expect {
          post :create, params: { test-with-hyphens_item: invalid_attributes }
        }.to change(TestWithHyphensItem, :count).by(0)
      end

      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: { test-with-hyphens_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { name: 'Updated Item', description: 'Updated Description' }
      end

      it 'updates the requested test-with-hyphens_item' do
        put :update, params: { id: test-with-hyphens_item.to_param, test-with-hyphens_item: new_attributes }
        test-with-hyphens_item.reload
        expect(test-with-hyphens_item.name).to eq('Updated Item')
      end

      it 'redirects to the test-with-hyphens_item' do
        put :update, params: { id: test-with-hyphens_item.to_param, test-with-hyphens_item: new_attributes }
        expect(response).to redirect_to(test-with-hyphens_item)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Updated Description' }
      end

      it "returns a success response (i.e. to display the 'edit' template)" do
        put :update, params: { id: test-with-hyphens_item.to_param, test-with-hyphens_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested test-with-hyphens_item' do
      test-with-hyphens_item # Create the item
      expect {
        delete :destroy, params: { id: test-with-hyphens_item.to_param }
      }.to change(TestWithHyphensItem, :count).by(-1)
    end

    it 'redirects to the test-with-hyphens_items list' do
      delete :destroy, params: { id: test-with-hyphens_item.to_param }
      expect(response).to redirect_to(test-with-hyphens_index_url)
    end
  end
end
