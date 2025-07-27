# frozen_string_literal: true

# DemoFeatureController handles demo_feature related requests
class DemoFeatureController < ApplicationController
  before_action :authenticate_user!
  before_action :set_demo_feature_item, only: [:show, :edit, :update, :destroy]

  # GET /demo_feature
  def index
    @demo_feature_items = current_user.demo_feature_items
  end

  # GET /demo_feature/1
  def show
  end

  # GET /demo_feature/new
  def new
    @demo_feature_item = current_user.demo_feature_items.build
  end

  # GET /demo_feature/1/edit
  def edit
  end

  # POST /demo_feature
  def create
    @demo_feature_item = current_user.demo_feature_items.build(demo_feature_item_params)

    if @demo_feature_item.save
      redirect_to @demo_feature_item, notice: 'DemoFeature item was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /demo_feature/1
  def update
    if @demo_feature_item.update(demo_feature_item_params)
      redirect_to @demo_feature_item, notice: 'DemoFeature item was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /demo_feature/1
  def destroy
    @demo_feature_item.destroy
    redirect_to demo_feature_index_url, notice: 'DemoFeature item was successfully deleted.'
  end

  private

  def set_demo_feature_item
    @demo_feature_item = current_user.demo_feature_items.find(params[:id])
  end

  def demo_feature_item_params
    params.require(:demo_feature_item).permit(:name, :description)
  end
end
