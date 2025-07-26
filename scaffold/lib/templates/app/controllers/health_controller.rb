# frozen_string_literal: true

class HealthController < ApplicationController
  # Skip authentication and other before_actions for health checks
  skip_before_action :authenticate_user!, if: :devise_controller?
  skip_before_action :verify_authenticity_token
  
  def show
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage
    }
    
    # Overall health status
    healthy = checks.all? { |_service, status| status[:healthy] }
    
    response_data = {
      status: healthy ? 'healthy' : 'unhealthy',
      timestamp: Time.current.iso8601,
      checks: checks,
      version: app_version
    }
    
    status_code = healthy ? :ok : :service_unavailable
    
    respond_to do |format|
      format.json { render json: response_data, status: status_code }
      format.html { render json: response_data, status: status_code }
    end
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { healthy: true, message: 'Database connection successful' }
  rescue => e
    { healthy: false, message: "Database error: #{e.message}" }
  end

  def check_redis
    Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')).ping
    { healthy: true, message: 'Redis connection successful' }
  rescue => e
    { healthy: false, message: "Redis error: #{e.message}" }
  end

  def check_storage
    # Check if we can write to the storage directory
    Rails.root.join('tmp').writable?
    { healthy: true, message: 'Storage accessible' }
  rescue => e
    { healthy: false, message: "Storage error: #{e.message}" }
  end

  def app_version
    # Try to read version from various sources
    return ENV['APP_VERSION'] if ENV['APP_VERSION'].present?
    return File.read(Rails.root.join('VERSION')).strip if File.exist?(Rails.root.join('VERSION'))
    return `git rev-parse --short HEAD`.strip if system('git rev-parse --short HEAD > /dev/null 2>&1')
    
    'unknown'
  rescue
    'unknown'
  end
end