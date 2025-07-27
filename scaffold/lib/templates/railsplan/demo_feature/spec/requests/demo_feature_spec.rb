# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "DemoFeature requests", type: :request do
  let(:user) { create(:user) }
  let(:demo_feature_item) { create(:demo_feature_item, user: user) }

  before do
    sign_in user
  end

  describe "GET /demo_feature" do
    it "returns http success" do
      get "/demo_feature"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /demo_feature/:id" do
    it "returns http success" do
      get "/demo_feature/#{demo_feature_item.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /demo_feature/new" do
    it "returns http success" do
      get "/demo_feature/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /demo_feature" do
    let(:valid_params) do
      { demo_feature_item: { name: "Test Item", description: "Test Description" } }
    end

    it "creates a new item and redirects" do
      expect {
        post "/demo_feature", params: valid_params
      }.to change(DemoFeatureItem, :count).by(1)
      
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /demo_feature/:id/edit" do
    it "returns http success" do
      get "/demo_feature/#{demo_feature_item.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /demo_feature/:id" do
    let(:valid_params) do
      { demo_feature_item: { name: "Updated Item" } }
    end

    it "updates the item and redirects" do
      patch "/demo_feature/#{demo_feature_item.id}", params: valid_params
      
      demo_feature_item.reload
      expect(demo_feature_item.name).to eq("Updated Item")
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /demo_feature/:id" do
    it "destroys the item and redirects" do
      demo_feature_item # Create the item
      
      expect {
        delete "/demo_feature/#{demo_feature_item.id}"
      }.to change(DemoFeatureItem, :count).by(-1)
      
      expect(response).to have_http_status(:redirect)
    end
  end
end
