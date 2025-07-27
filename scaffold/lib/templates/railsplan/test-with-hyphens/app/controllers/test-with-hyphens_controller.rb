# frozen_string_literal: true

# TestWithHyphensController handles test-with-hyphens related requests
class TestWithHyphensController < ApplicationController
  before_action :authenticate_user!
  before_action :set_test-with-hyphens_item, only: [:show, :edit, :update, :destroy]

  # GET /test-with-hyphens
  def index
    @test-with-hyphens_items = current_user.test-with-hyphens_items
  end

  # GET /test-with-hyphens/1
  def show
  end

  # GET /test-with-hyphens/new
  def new
    @test-with-hyphens_item = current_user.test-with-hyphens_items.build
  end

  # GET /test-with-hyphens/1/edit
  def edit
  end

  # POST /test-with-hyphens
  def create
    @test-with-hyphens_item = current_user.test-with-hyphens_items.build(test-with-hyphens_item_params)

    if @test-with-hyphens_item.save
      redirect_to @test-with-hyphens_item, notice: 'TestWithHyphens item was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /test-with-hyphens/1
  def update
    if @test-with-hyphens_item.update(test-with-hyphens_item_params)
      redirect_to @test-with-hyphens_item, notice: 'TestWithHyphens item was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /test-with-hyphens/1
  def destroy
    @test-with-hyphens_item.destroy
    redirect_to test-with-hyphens_index_url, notice: 'TestWithHyphens item was successfully deleted.'
  end

  private

  def set_test-with-hyphens_item
    @test-with-hyphens_item = current_user.test-with-hyphens_items.find(params[:id])
  end

  def test-with-hyphens_item_params
    params.require(:test-with-hyphens_item).permit(:name, :description)
  end
end
