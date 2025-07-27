# frozen_string_literal: true

class AgentWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:receive]
  before_action :authenticate_webhook, only: [:receive]

  # POST /api/v1/agents/:agent_id/webhook
  def receive
    agent_id = params[:agent_id]
    user_input = params[:user_input] || params[:message] || ""
    webhook_context = params[:context] || {}
    streaming = params[:streaming] == true || params[:streaming] == 'true'

    Rails.logger.info "Agent webhook received", {
      agent_id: agent_id,
      user_input_length: user_input.length,
      context_keys: webhook_context.keys,
      streaming: streaming
    }

    begin
      if streaming
        # For streaming, we need to use Server-Sent Events
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'

        # Stream the response
        AgentRunner.run(agent_id, user_input, context: webhook_context, streaming: true) do |content, type|
          case type
          when :chunk
            response.stream.write("data: #{json_encode({ type: 'chunk', content: content })}\n\n")
          when :complete
            response.stream.write("data: #{json_encode({ type: 'complete', content: content })}\n\n")
            response.stream.write("data: [DONE]\n\n")
          end
        end
      else
        # Synchronous response
        result = AgentRunner.run(agent_id, user_input, context: webhook_context)
        
        render json: {
          status: 'success',
          agent_id: agent_id,
          response: result,
          timestamp: Time.current.iso8601
        }
      end

    rescue ArgumentError => e
      render json: {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }, status: :not_found

    rescue => e
      Rails.logger.error "Agent webhook execution failed", {
        agent_id: agent_id,
        error: e.message,
        backtrace: e.backtrace&.first(5)
      }

      render json: {
        status: 'error',
        error: 'execution_failed',
        message: e.message
      }, status: :internal_server_error

    ensure
      response.stream.close if streaming && response.stream
    end
  end

  # POST /api/v1/agents/:agent_id/run
  def run
    agent_id = params[:agent_id]
    user_input = params[:user_input] || params[:message] || ""
    context = params[:context] || {}
    user = current_user # Assumes authentication is handled elsewhere

    begin
      result = AgentRunner.run(agent_id, user_input, user: user, context: context)
      
      render json: {
        status: 'success',
        agent_id: agent_id,
        response: result,
        timestamp: Time.current.iso8601
      }

    rescue ArgumentError => e
      render json: {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }, status: :not_found

    rescue => e
      Rails.logger.error "Agent API execution failed", {
        agent_id: agent_id,
        user_id: user&.id,
        error: e.message
      }

      render json: {
        status: 'error',
        error: 'execution_failed',
        message: e.message
      }, status: :internal_server_error
    end
  end

  # GET /api/v1/agents/:agent_id/config
  def config
    agent_id = params[:agent_id]
    
    begin
      runner = AgentRunner.new(agent_id)
      config = runner.agent_config
      summary = runner.agent.summary

      render json: {
        status: 'success',
        agent: summary,
        config: config,
        streaming_available: runner.streaming_available?
      }

    rescue ArgumentError => e
      render json: {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }, status: :not_found
    end
  end

  # POST /api/v1/agents/:agent_id/async
  def run_async
    agent_id = params[:agent_id]
    user_input = params[:user_input] || params[:message] || ""
    context = params[:context] || {}
    user = current_user

    begin
      runner = AgentRunner.new(agent_id, user: user, context: context)
      job_result = runner.run_async(user_input)
      
      render json: {
        status: 'accepted',
        agent_id: agent_id,
        job_id: job_result.job_id,
        message: 'Agent execution queued for background processing',
        timestamp: Time.current.iso8601
      }, status: :accepted

    rescue ArgumentError => e
      render json: {
        status: 'error',
        error: 'invalid_agent',
        message: e.message
      }, status: :not_found

    rescue => e
      Rails.logger.error "Agent async execution failed", {
        agent_id: agent_id,
        user_id: user&.id,
        error: e.message
      }

      render json: {
        status: 'error',
        error: 'execution_failed',
        message: e.message
      }, status: :internal_server_error
    end
  end

  private

  def authenticate_webhook
    # Simple token-based authentication for webhooks
    # In production, you'd want something more sophisticated
    webhook_token = request.headers['X-Webhook-Token'] || params[:webhook_token]
    
    unless webhook_token.present? && valid_webhook_token?(webhook_token)
      render json: { error: 'unauthorized', message: 'Invalid webhook token' }, status: :unauthorized
    end
  end

  def valid_webhook_token?(token)
    # This should be configurable per workspace/agent
    # For now, we'll check against a simple environment variable
    expected_token = ENV['AGENT_WEBHOOK_TOKEN'] || 'default-webhook-token'
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end

  def json_encode(data)
    JSON.generate(data)
  end

  def current_user
    # This would typically be handled by your authentication system
    # For webhook endpoints, you might extract user from context or token
    nil
  end
end