# frozen_string_literal: true

class Admin::FallbackAiCredentialsController < Admin::BaseController
  before_action :set_fallback_credential, only: [:show, :edit, :update, :destroy, :toggle_active, :test_connection]
  before_action :set_ai_providers, only: [:new, :edit, :create, :update]

  def index
    @fallback_credentials = FallbackAiCredential.includes(:ai_provider, :created_by)
                                               .order(:ai_provider_id, :priority, :name)
    
    # Apply filters
    @fallback_credentials = @fallback_credentials.joins(:ai_provider)
                                                .where(ai_providers: { slug: params[:provider] }) if params[:provider].present?
    @fallback_credentials = @fallback_credentials.where(active: params[:active] == 'true') if params[:active].present?
    
    # For filter dropdowns
    @providers = AiProvider.active.order(:name)
    @stats = calculate_global_stats
  end

  def show
    @usage_stats = @fallback_credential.usage_stats
    @recent_usage = @fallback_credential.fallback_credential_usages
                                       .includes(:user, :workspace)
                                       .recent
                                       .limit(20)
    
    @daily_usage_chart_data = @fallback_credential.fallback_credential_usages
                                                  .where(date: 30.days.ago..Date.current)
                                                  .group(:date)
                                                  .sum(:usage_count)
  end

  def new
    @fallback_credential = FallbackAiCredential.new
  end

  def create
    @fallback_credential = FallbackAiCredential.new(fallback_credential_params)
    @fallback_credential.created_by = current_user

    if @fallback_credential.save
      redirect_to admin_fallback_ai_credential_path(@fallback_credential), 
                  notice: 'Fallback AI credential was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @fallback_credential.update(fallback_credential_params)
      redirect_to admin_fallback_ai_credential_path(@fallback_credential), 
                  notice: 'Fallback AI credential was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @fallback_credential.destroy
    redirect_to admin_fallback_ai_credentials_path, 
                notice: 'Fallback AI credential was successfully deleted.'
  end

  def toggle_active
    @fallback_credential.update!(active: !@fallback_credential.active?)
    
    status = @fallback_credential.active? ? 'activated' : 'deactivated'
    redirect_to admin_fallback_ai_credentials_path, 
                notice: "Fallback credential '#{@fallback_credential.name}' was #{status}."
  end

  def test_connection
    result = @fallback_credential.test_connection
    
    if result[:success]
      flash[:notice] = "Connection test successful: #{result[:message]}"
    else
      flash[:alert] = "Connection test failed: #{result[:error]}"
    end
    
    redirect_to admin_fallback_ai_credential_path(@fallback_credential)
  end

  def usage_report
    @credentials = FallbackAiCredential.includes(:ai_provider, :fallback_credential_usages)
                                      .order(:name)
    
    # Date range for report
    @start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    @end_date = params[:end_date]&.to_date || Date.current
    
    @usage_data = FallbackCredentialUsage.joins(:fallback_ai_credential, :user)
                                        .where(date: @start_date..@end_date)
                                        .group('fallback_ai_credentials.name', 'users.email', :date)
                                        .sum(:usage_count)
    
    respond_to do |format|
      format.html
      format.csv do
        send_data generate_usage_csv(@usage_data, @start_date, @end_date),
                  filename: "fallback_credentials_usage_#{@start_date}_to_#{@end_date}.csv"
      end
    end
  end

  def bulk_toggle
    credential_ids = params[:credential_ids] || []
    action = params[:bulk_action]
    
    if credential_ids.any? && %w[activate deactivate].include?(action)
      active_status = action == 'activate'
      FallbackAiCredential.where(id: credential_ids).update_all(active: active_status)
      
      flash[:notice] = "#{credential_ids.count} credentials were #{action}d."
    else
      flash[:alert] = "Please select credentials and a valid action."
    end
    
    redirect_to admin_fallback_ai_credentials_path
  end

  private

  def set_fallback_credential
    @fallback_credential = FallbackAiCredential.find(params[:id])
  end

  def set_ai_providers
    @ai_providers = AiProvider.active.order(:name)
  end

  def fallback_credential_params
    params.require(:fallback_ai_credential).permit(
      :ai_provider_id, :name, :description, :api_key, :preferred_model,
      :temperature, :max_tokens, :response_format, :system_prompt,
      :active, :priority, :usage_limit, :daily_limit, :expires_at,
      :enabled_for_onboarding, :enabled_for_trials, :onboarding_message,
      provider_config: {}
    )
  end

  def calculate_global_stats
    {
      total_credentials: FallbackAiCredential.count,
      active_credentials: FallbackAiCredential.active.count,
      total_usage_today: FallbackCredentialUsage.today.sum(:usage_count),
      total_usage_this_month: FallbackCredentialUsage.current_month.sum(:usage_count),
      unique_users_today: FallbackCredentialUsage.today.distinct.count(:user_id),
      unique_users_this_month: FallbackCredentialUsage.current_month.distinct.count(:user_id)
    }
  end

  def generate_usage_csv(usage_data, start_date, end_date)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Credential Name', 'User Email', 'Date', 'Usage Count']
      
      usage_data.each do |(credential_name, user_email, date), usage_count|
        csv << [credential_name, user_email, date, usage_count]
      end
    end
  end
end