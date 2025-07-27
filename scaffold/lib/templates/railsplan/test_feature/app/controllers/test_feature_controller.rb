# frozen_string_literal: true

# TestFeatureController handles test_feature related requests
class TestFeatureController < ApplicationController
  before_action :authenticate_user!
  before_action :set_test_feature_item, only: [:show, :edit, :update, :destroy]

  # GET /test_feature
  def index
    @test_feature_items = current_user.test_feature_items
  end

  # GET /test_feature/1
  def show
  end

  # GET /test_feature/new
  def new
    @test_feature_item = current_user.test_feature_items.build
  end

  # GET /test_feature/1/edit
  def edit
  end

  # POST /test_feature
  def create
    @test_feature_item = current_user.test_feature_items.build(test_feature_item_params)

    if @test_feature_item.save
      redirect_to @test_feature_item, notice: 'TestFeature item was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /test_feature/1
  def update
    if @test_feature_item.update(test_feature_item_params)
      redirect_to @test_feature_item, notice: 'TestFeature item was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /test_feature/1
  def destroy
    @test_feature_item.destroy
    redirect_to test_feature_index_url, notice: 'TestFeature item was successfully deleted.'
  end

  private

  def set_test_feature_item
    @test_feature_item = current_user.test_feature_items.find(params[:id])
  end

  def test_feature_item_params
    params.require(:test_feature_item).permit(:name, :description)
  end
end
