# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "TestFeature requests", type: :request do
  let(:user) { create(:user) }
  let(:test_feature_item) { create(:test_feature_item, user: user) }

  before do
    sign_in user
  end

  describe "GET /test_feature" do
    it "returns http success" do
      get "/test_feature"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /test_feature/:id" do
    it "returns http success" do
      get "/test_feature/#{test_feature_item.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /test_feature/new" do
    it "returns http success" do
      get "/test_feature/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /test_feature" do
    let(:valid_params) do
      { test_feature_item: { name: "Test Item", description: "Test Description" } }
    end

    it "creates a new item and redirects" do
      expect {
        post "/test_feature", params: valid_params
      }.to change(TestFeatureItem, :count).by(1)
      
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /test_feature/:id/edit" do
    it "returns http success" do
      get "/test_feature/#{test_feature_item.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /test_feature/:id" do
    let(:valid_params) do
      { test_feature_item: { name: "Updated Item" } }
    end

    it "updates the item and redirects" do
      patch "/test_feature/#{test_feature_item.id}", params: valid_params
      
      test_feature_item.reload
      expect(test_feature_item.name).to eq("Updated Item")
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /test_feature/:id" do
    it "destroys the item and redirects" do
      test_feature_item # Create the item
      
      expect {
        delete "/test_feature/#{test_feature_item.id}"
      }.to change(TestFeatureItem, :count).by(-1)
      
      expect(response).to have_http_status(:redirect)
    end
  end
end
