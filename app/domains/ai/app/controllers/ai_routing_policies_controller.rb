# frozen_string_literal: true

class AiRoutingPoliciesController < ApplicationController
  before_action :set_workspace
  before_action :set_ai_routing_policy, only: [:show, :edit, :update, :destroy]

  def index
    @ai_routing_policies = @workspace.ai_routing_policies.order(:name)
    @spending_limit = @workspace.workspace_spending_limit || 
                     @workspace.build_workspace_spending_limit
  end

  def show
    @spending_summary = @workspace.workspace_spending_limit&.spending_summary || {}
    @recent_outputs = @workspace.llm_outputs.recent.limit(10)
  end

  def new
    @ai_routing_policy = @workspace.ai_routing_policies.build
    set_defaults
  end

  def create
    @ai_routing_policy = @workspace.ai_routing_policies.build(ai_routing_policy_params)
    @ai_routing_policy.created_by = current_user
    @ai_routing_policy.updated_by = current_user

    if @ai_routing_policy.save
      redirect_to [@workspace, @ai_routing_policy], 
                  notice: 'AI routing policy was successfully created.'
    else
      set_defaults
      render :new
    end
  end

  def edit
  end

  def update
    @ai_routing_policy.updated_by = current_user

    if @ai_routing_policy.update(ai_routing_policy_params)
      redirect_to [@workspace, @ai_routing_policy], 
                  notice: 'AI routing policy was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @ai_routing_policy.destroy
    redirect_to workspace_ai_routing_policies_url(@workspace), 
                notice: 'AI routing policy was successfully deleted.'
  end

  # Preview endpoint for testing routing logic
  def preview
    @ai_routing_policy = @workspace.ai_routing_policies.find(params[:id])
    
    sample_prompt = params[:sample_prompt] || "Analyze the following data and provide insights..."
    input_tokens = @ai_routing_policy.class.new.send(:estimate_tokens, sample_prompt)
    max_output_tokens = 500

    @preview_data = {
      sample_prompt: sample_prompt,
      input_tokens: input_tokens,
      max_output_tokens: max_output_tokens,
      models: @ai_routing_policy.ordered_models.map do |model|
        estimated_cost = @ai_routing_policy.estimate_cost(input_tokens, max_output_tokens, model)
        cost_check = @ai_routing_policy.cost_check(estimated_cost)
        
        {
          model: model,
          estimated_cost: estimated_cost,
          cost_check: cost_check,
          available: AiRoutingPolicy::MODEL_COSTS.key?(model)
        }
      end,
      routing_rules: @ai_routing_policy.effective_routing_rules,
      cost_rules: @ai_routing_policy.effective_cost_rules
    }

    render json: @preview_data
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:workspace_id])
  end

  def set_ai_routing_policy
    @ai_routing_policy = @workspace.ai_routing_policies.find(params[:id])
  end

  def ai_routing_policy_params
    params.require(:ai_routing_policy).permit(
      :name, :primary_model, :cost_threshold_warning, :cost_threshold_block,
      :enabled, :description, :routing_rules, :cost_rules,
      fallback_models: []
    )
  end

  def set_defaults
    @available_models = AiRoutingPolicy::MODEL_COSTS.keys
    @default_fallbacks = @ai_routing_policy.send(:default_fallbacks_for_model, 
                                                 @ai_routing_policy.primary_model) if @ai_routing_policy.primary_model
  end
end