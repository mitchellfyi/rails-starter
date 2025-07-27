# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "TestWithHyphens requests", type: :request do
  let(:user) { create(:user) }
  let(:test-with-hyphens_item) { create(:test-with-hyphens_item, user: user) }

  before do
    sign_in user
  end

  describe "GET /test-with-hyphens" do
    it "returns http success" do
      get "/test-with-hyphens"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /test-with-hyphens/:id" do
    it "returns http success" do
      get "/test-with-hyphens/#{test-with-hyphens_item.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /test-with-hyphens/new" do
    it "returns http success" do
      get "/test-with-hyphens/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /test-with-hyphens" do
    let(:valid_params) do
      { test-with-hyphens_item: { name: "Test Item", description: "Test Description" } }
    end

    it "creates a new item and redirects" do
      expect {
        post "/test-with-hyphens", params: valid_params
      }.to change(TestWithHyphensItem, :count).by(1)
      
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /test-with-hyphens/:id/edit" do
    it "returns http success" do
      get "/test-with-hyphens/#{test-with-hyphens_item.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /test-with-hyphens/:id" do
    let(:valid_params) do
      { test-with-hyphens_item: { name: "Updated Item" } }
    end

    it "updates the item and redirects" do
      patch "/test-with-hyphens/#{test-with-hyphens_item.id}", params: valid_params
      
      test-with-hyphens_item.reload
      expect(test-with-hyphens_item.name).to eq("Updated Item")
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /test-with-hyphens/:id" do
    it "destroys the item and redirects" do
      test-with-hyphens_item # Create the item
      
      expect {
        delete "/test-with-hyphens/#{test-with-hyphens_item.id}"
      }.to change(TestWithHyphensItem, :count).by(-1)
      
      expect(response).to have_http_status(:redirect)
    end
  end
end
