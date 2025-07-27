# frozen_string_literal: true

# Notifications controller for in-app notification management
class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :update, :destroy]
  
  # GET /notifications
  def index
    @notifications = current_user.notifications
                                .includes(:event)
                                .recent
                                .page(params[:page])
                                .per(20)
    
    # Mark all as seen when viewing the index
    current_user.notifications.unread.update_all(read_at: Time.current)
  end
  
  # GET /notifications/:id
  def show
    @notification.mark_as_read!
    redirect_to @notification.action_url
  end
  
  # PATCH /notifications/:id
  def update
    @notification.mark_as_read!
    
    respond_to do |format|
      format.json { render json: { status: 'read' } }
      format.html { redirect_back(fallback_location: notifications_path) }
    end
  end
  
  # DELETE /notifications/:id
  def destroy
    @notification.destroy
    
    respond_to do |format|
      format.json { render json: { status: 'deleted' } }
      format.html { redirect_to notifications_path, notice: 'Notification deleted.' }
    end
  end
  
  # POST /notifications/mark_all_read
  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    
    respond_to do |format|
      format.json { render json: { status: 'all_read' } }
      format.html { redirect_to notifications_path, notice: 'All notifications marked as read.' }
    end
  end
  
  # GET /notifications/unread_count
  def unread_count
    count = current_user.notifications.unread.count
    render json: { count: count }
  end
  
  private
  
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end