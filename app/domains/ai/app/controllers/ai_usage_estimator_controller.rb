# frozen_string_literal: true

class AiUsageEstimatorController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, if: -> { params[:workspace_id] }
  before_action :initialize_estimator

  # GET /ai_usage_estimator
  def index
    @available_models = @estimator.available_models
    @sample_templates = sample_templates
    @ai_credentials = current_workspace&.ai_credentials || AiCredential.none
  end

  # POST /ai_usage_estimator/estimate
  def estimate
    template = params.require(:template)
    model = params.require(:model)
    context = params.fetch(:context, {})
    format = params.fetch(:format, 'text')

    # Validate format
    unless %w[text json markdown html].include?(format)
      render json: { 
        error: 'Invalid format', 
        valid_formats: %w[text json markdown html] 
      }, status: :bad_request
      return
    end

    # Validate context is a hash
    unless context.is_a?(Hash)
      render json: { 
        error: 'Context must be a hash/object' 
      }, status: :bad_request
      return
    end

    estimation = @estimator.estimate_single(
      template: template,
      model: model,
      context: context,
      format: format
    )

    respond_to do |format_type|
      format_type.json { render json: { estimation: estimation } }
      format_type.html { 
        @estimation = estimation
        @template = template
        @model = model
        @context = context
        @format = format
        render :estimate 
      }
    end

  rescue ActionController::ParameterMissing => e
    respond_to do |format_type|
      format_type.json { 
        render json: { 
          error: "Missing required parameter: #{e.param}" 
        }, status: :bad_request 
      }
      format_type.html { 
        redirect_to ai_usage_estimator_index_path, 
        alert: "Missing required parameter: #{e.param}" 
      }
    end
  rescue => e
    Rails.logger.error "Error in AI usage estimation: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format_type|
      format_type.json { 
        render json: { 
          error: 'Failed to calculate estimation', 
          details: e.message 
        }, status: :internal_server_error 
      }
      format_type.html { 
        redirect_to ai_usage_estimator_index_path, 
        alert: "Failed to calculate estimation: #{e.message}" 
      }
    end
  end

  # POST /ai_usage_estimator/batch_estimate
  def batch_estimate
    template = params.require(:template)
    model = params.require(:model)
    format = params.fetch(:format, 'text')

    # Handle file upload or direct input data
    inputs = if params[:file].present?
      parse_uploaded_file(params[:file])
    elsif params[:inputs].present?
      parse_input_data(params[:inputs])
    else
      raise ActionController::ParameterMissing.new(:file_or_inputs)
    end

    # Validate we have inputs
    if inputs.empty?
      render json: { 
        error: 'No valid inputs found' 
      }, status: :bad_request
      return
    end

    # Limit batch size for performance
    max_batch_size = 1000
    if inputs.length > max_batch_size
      render json: { 
        error: "Batch size too large. Maximum #{max_batch_size} inputs allowed.",
        provided: inputs.length
      }, status: :bad_request
      return
    end

    estimation = @estimator.estimate_batch(
      inputs,
      template: template,
      model: model,
      format: format
    )

    respond_to do |format_type|
      format_type.json { render json: { batch_estimation: estimation } }
      format_type.html { 
        @batch_estimation = estimation
        @template = template
        @model = model
        @format = format
        @inputs_count = inputs.length
        render :batch_estimate 
      }
    end

  rescue ActionController::ParameterMissing => e
    respond_to do |format_type|
      format_type.json { 
        render json: { 
          error: "Missing required parameter: #{e.param}" 
        }, status: :bad_request 
      }
      format_type.html { 
        redirect_to ai_usage_estimator_index_path, 
        alert: "Missing required parameter: #{e.param}" 
      }
    end
  rescue => e
    Rails.logger.error "Error in batch AI usage estimation: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format_type|
      format_type.json { 
        render json: { 
          error: 'Failed to calculate batch estimation', 
          details: e.message 
        }, status: :internal_server_error 
      }
      format_type.html { 
        redirect_to ai_usage_estimator_index_path, 
        alert: "Failed to calculate batch estimation: #{e.message}" 
      }
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Workspace not found'
  end

  def current_workspace
    @workspace || current_user&.current_workspace
  end

  def initialize_estimator
    ai_credential = if params[:ai_credential_id].present?
      current_workspace&.ai_credentials&.find(params[:ai_credential_id])
    else
      current_workspace&.ai_credentials&.first
    end

    @estimator = AiUsageEstimatorService.new(
      workspace: current_workspace,
      ai_credential: ai_credential
    )
  end

  def parse_uploaded_file(file)
    case File.extname(file.original_filename).downcase
    when '.json'
      data = JSON.parse(file.read)
      # Expect array of objects or single object
      data.is_a?(Array) ? data : [data]
    when '.csv'
      require 'csv'
      csv_data = CSV.parse(file.read, headers: true)
      csv_data.map(&:to_h)
    else
      raise "Unsupported file format. Please upload JSON or CSV files."
    end
  rescue JSON::ParserError => e
    raise "Invalid JSON file: #{e.message}"
  rescue CSV::MalformedCSVError => e
    raise "Invalid CSV file: #{e.message}"
  end

  def parse_input_data(inputs_param)
    # Handle both JSON string and direct array/hash
    if inputs_param.is_a?(String)
      data = JSON.parse(inputs_param)
    else
      data = inputs_param
    end

    # Ensure it's an array
    data.is_a?(Array) ? data : [data]
  rescue JSON::ParserError => e
    raise "Invalid input data format: #{e.message}"
  end

  def sample_templates
    [
      {
        name: "Content Summarization",
        template: "Please summarize the following content in {{style}} style:\n\n{{content}}",
        sample_context: { content: "Lorem ipsum dolor sit amet...", style: "bullet points" }
      },
      {
        name: "Code Review",
        template: "Review this {{language}} code and provide feedback:\n\n```{{language}}\n{{code}}\n```",
        sample_context: { language: "ruby", code: "def hello\n  puts 'world'\nend" }
      },
      {
        name: "Translation",
        template: "Translate the following text from {{source_lang}} to {{target_lang}}:\n\n{{text}}",
        sample_context: { source_lang: "English", target_lang: "Spanish", text: "Hello, how are you?" }
      },
      {
        name: "Data Analysis",
        template: "Analyze this data and provide insights:\n\nData: {{data}}\nContext: {{context}}",
        sample_context: { data: "[1, 2, 3, 4, 5]", context: "Sales figures for last 5 months" }
      }
    ]
  end
end