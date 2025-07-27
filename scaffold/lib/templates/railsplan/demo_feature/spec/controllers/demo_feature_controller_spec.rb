# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DemoFeatureController, type: :controller do
  let(:user) { create(:user) }
  let(:demo_feature_item) { create(:demo_feature_item, user: user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @demo_feature_items' do
      demo_feature_item # Create the item
      get :index
      expect(assigns(:demo_feature_items)).to include(demo_feature_item)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: demo_feature_item.to_param }
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
      get :edit, params: { id: demo_feature_item.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        { name: 'Test Item', description: 'Test Description' }
      end

      it 'creates a new DemoFeatureItem' do
        expect {
          post :create, params: { demo_feature_item: valid_attributes }
        }.to change(DemoFeatureItem, :count).by(1)
      end

      it 'redirects to the created demo_feature_item' do
        post :create, params: { demo_feature_item: valid_attributes }
        expect(response).to redirect_to(DemoFeatureItem.last)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Test Description' }
      end

      it 'does not create a new DemoFeatureItem' do
        expect {
          post :create, params: { demo_feature_item: invalid_attributes }
        }.to change(DemoFeatureItem, :count).by(0)
      end

      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: { demo_feature_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { name: 'Updated Item', description: 'Updated Description' }
      end

      it 'updates the requested demo_feature_item' do
        put :update, params: { id: demo_feature_item.to_param, demo_feature_item: new_attributes }
        demo_feature_item.reload
        expect(demo_feature_item.name).to eq('Updated Item')
      end

      it 'redirects to the demo_feature_item' do
        put :update, params: { id: demo_feature_item.to_param, demo_feature_item: new_attributes }
        expect(response).to redirect_to(demo_feature_item)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { name: '', description: 'Updated Description' }
      end

      it "returns a success response (i.e. to display the 'edit' template)" do
        put :update, params: { id: demo_feature_item.to_param, demo_feature_item: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested demo_feature_item' do
      demo_feature_item # Create the item
      expect {
        delete :destroy, params: { id: demo_feature_item.to_param }
      }.to change(DemoFeatureItem, :count).by(-1)
    end

    it 'redirects to the demo_feature_items list' do
      delete :destroy, params: { id: demo_feature_item.to_param }
      expect(response).to redirect_to(demo_feature_index_url)
    end
  end
end
