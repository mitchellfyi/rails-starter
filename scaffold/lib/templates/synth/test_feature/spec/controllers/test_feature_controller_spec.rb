# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestFeatureController, type: :controller do
  let(:user) { create(:user) }
  let(:test_feature_item) { create(:test_feature_item, user: user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @test_feature_items' do
      test_feature_item # Create the item
      get :index
      expect(assigns(:test_feature_items)).to include(test_feature_item)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: test_feature_item.to_param }
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
      get :edit, params: { id: test_feature_item.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        { name: 'Test Item', description: 'Test Description' }
      end

      it 'creates a new TestFeatureItem' do
        expect {
          post :create, params: { test_feature_item: valid_attributes }
        }.to change(TestFeatureItem, :count).by(1)
      end

      it 'redirects to the created test_feature_item' do
        post :create, params: { test_feature_item: valid_attributes }
        expect(response).to redirect_to(TestFeatureItem.last)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Test Description' }
      end

      it 'does not create a new TestFeatureItem' do
        expect {
          post :create, params: { test_feature_item: invalid_attributes }
        }.to change(TestFeatureItem, :count).by(0)
      end

      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: { test_feature_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { name: 'Updated Item', description: 'Updated Description' }
      end

      it 'updates the requested test_feature_item' do
        put :update, params: { id: test_feature_item.to_param, test_feature_item: new_attributes }
        test_feature_item.reload
        expect(test_feature_item.name).to eq('Updated Item')
      end

      it 'redirects to the test_feature_item' do
        put :update, params: { id: test_feature_item.to_param, test_feature_item: new_attributes }
        expect(response).to redirect_to(test_feature_item)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Updated Description' }
      end

      it "returns a success response (i.e. to display the 'edit' template)" do
        put :update, params: { id: test_feature_item.to_param, test_feature_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested test_feature_item' do
      test_feature_item # Create the item
      expect {
        delete :destroy, params: { id: test_feature_item.to_param }
      }.to change(TestFeatureItem, :count).by(-1)
    end

    it 'redirects to the test_feature_items list' do
      delete :destroy, params: { id: test_feature_item.to_param }
      expect(response).to redirect_to(test_feature_index_url)
    end
  end
end
