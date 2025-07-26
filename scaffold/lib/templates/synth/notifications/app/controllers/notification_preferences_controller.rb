# frozen_string_literal: true

class NotificationPreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification_preference

  def show
    respond_to do |format|
      format.html
      format.json { render json: { preferences: preferences_json } }
    end
  end

  def update
    if @notification_preference.update(notification_preference_params)
      respond_to do |format|
        format.html { redirect_to notification_preferences_path, notice: 'Notification preferences updated.' }
        format.json { render json: { preferences: preferences_json } }
      end
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: { errors: @notification_preference.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_notification_preference
    @notification_preference = NotificationPreference.for_user(current_user)
  end

  def notification_preference_params
    params.require(:notification_preference).permit(
      :email_notifications,
      :in_app_notifications,
      notification_types: {}
    )
  end

  def preferences_json
    {
      id: @notification_preference.id,
      email_notifications: @notification_preference.email_notifications,
      in_app_notifications: @notification_preference.in_app_notifications,
      notification_types: @notification_preference.notification_types,
      available_types: Notification::TYPES.map do |type|
        {
          type: type,
          label: type.humanize,
          default_email: NotificationPreference.default_preferences[type]['email'],
          default_in_app: NotificationPreference.default_preferences[type]['in_app']
        }
      end
    }
  end
end