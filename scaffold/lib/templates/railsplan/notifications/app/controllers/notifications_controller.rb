# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :update, :destroy, :read, :dismiss]

  def index
    @notifications = current_user.notifications
                                .active
                                .recent
                                .page(params[:page])
                                .per(20)

    respond_to do |format|
      format.html
      format.json { render json: { notifications: notifications_json } }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: { notification: notification_json(@notification) } }
    end
  end

  def update
    if @notification.update(notification_params)
      respond_to do |format|
        format.html { redirect_to notifications_path, notice: 'Notification updated.' }
        format.json { render json: { notification: notification_json(@notification) } }
      end
    else
      respond_to do |format|
        format.html { render :show }
        format.json { render json: { errors: @notification.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @notification.destroy
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'Notification deleted.' }
      format.json { head :no_content }
    end
  end

  def read
    @notification.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: notifications_path) }
      format.json { render json: { notification: notification_json(@notification) } }
    end
  end

  def dismiss
    @notification.dismiss!
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'Notification dismissed.' }
      format.json { head :no_content }
    end
  end

  def mark_all_read
    Notification.mark_all_read_for_user(current_user)
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'All notifications marked as read.' }
      format.json { head :no_content }
    end
  end

  def dismiss_all
    Notification.dismiss_all_for_user(current_user)
    
    respond_to do |format|
      format.html { redirect_to notifications_path, notice: 'All notifications dismissed.' }
      format.json { head :no_content }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end

  def notification_params
    params.require(:notification).permit(:read_at)
  end

  def notifications_json
    @notifications.map { |notification| notification_json(notification) }
  end

  def notification_json(notification)
    {
      id: notification.id,
      type: notification.notification_type,
      title: notification.title,
      message: notification.message,
      data: notification.data,
      read: notification.read?,
      dismissed: notification.dismissed?,
      icon: notification.icon,
      priority: notification.priority,
      created_at: notification.created_at.iso8601,
      read_at: notification.read_at&.iso8601,
      dismissed_at: notification.dismissed_at&.iso8601
    }
  end
end