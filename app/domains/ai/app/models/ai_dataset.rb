# frozen_string_literal: true

# Model for managing training and embedding datasets for AI customization
class AiDataset < ApplicationRecord
  belongs_to :workspace
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  has_many :workspace_embedding_sources, dependent: :destroy
  has_many_attached :files

  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :dataset_type, presence: true, inclusion: { in: %w[embedding fine-tune] }
  validates :processed_status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :by_type, ->(type) { where(dataset_type: type) if type.present? }
  scope :by_status, ->(status) { where(processed_status: status) if status.present? }
  scope :for_workspace, ->(workspace) { where(workspace: workspace) if workspace.present? }
  scope :completed, -> { where(processed_status: 'completed') }
  scope :failed, -> { where(processed_status: 'failed') }

  # Check if dataset is ready for use
  def ready?
    processed_status == 'completed'
  end

  # Check if dataset is currently being processed
  def processing?
    processed_status == 'processing'
  end

  # Mark dataset as processing
  def mark_processing!
    update!(processed_status: 'processing', processed_at: Time.current)
  end

  # Mark dataset as completed
  def mark_completed!
    update!(processed_status: 'completed', processed_at: Time.current)
  end

  # Mark dataset as failed
  def mark_failed!(error_message = nil)
    update!(
      processed_status: 'failed', 
      processed_at: Time.current,
      error_message: error_message
    )
  end

  # Get file count
  def file_count
    files.count
  end

  # Get total file size in bytes
  def total_file_size
    files.sum(&:byte_size)
  end

  # Get total file size in human readable format
  def total_file_size_human
    ActionController::Base.helpers.number_to_human_size(total_file_size)
  end

  # Check if dataset can be processed
  def can_process?
    files.any? && %w[pending failed].include?(processed_status)
  end

  # Get processing stats
  def processing_stats
    {
      file_count: file_count,
      total_size: total_file_size,
      status: processed_status,
      created_at: created_at,
      processed_at: processed_at,
      error_message: error_message
    }
  end

  # Create embeddings from dataset files
  def create_embeddings!
    return unless dataset_type == 'embedding' && can_process?

    mark_processing!
    
    begin
      files.each do |file|
        content = file.download
        
        # Process based on file type
        case file.content_type
        when 'text/plain', 'text/markdown'
          create_text_embeddings(content, file)
        when 'application/json'
          create_json_embeddings(content, file)
        else
          Rails.logger.warn "Unsupported file type for embeddings: #{file.content_type}"
        end
      end
      
      mark_completed!
    rescue => error
      mark_failed!(error.message)
      raise
    end
  end

  # Initiate fine-tuning process
  def initiate_fine_tuning!
    return unless dataset_type == 'fine-tune' && can_process?

    mark_processing!
    
    # This would integrate with OpenAI fine-tuning API
    # For now, we'll just mark as completed
    # In a real implementation, this would:
    # 1. Upload files to OpenAI
    # 2. Create fine-tuning job
    # 3. Monitor job status
    # 4. Store fine-tuned model ID
    
    begin
      # Placeholder for fine-tuning logic
      Rails.logger.info "Initiating fine-tuning for dataset #{id}"
      
      # Simulate processing
      sleep(1) if Rails.env.development?
      
      mark_completed!
    rescue => error
      mark_failed!(error.message)
      raise
    end
  end

  private

  def create_text_embeddings(content, file)
    # Split content into chunks for embedding
    chunks = split_text_into_chunks(content.force_encoding('UTF-8'))
    
    chunks.each_with_index do |chunk, index|
      VectorEmbedding.create!(
        content: chunk,
        content_type: 'dataset_chunk',
        namespace: "dataset_#{id}",
        metadata: {
          dataset_id: id,
          file_name: file.filename.to_s,
          chunk_index: index,
          source_type: 'ai_dataset'
        },
        workspace: workspace,
        embedding: generate_embedding_vector(chunk)
      )
    end
  end

  def create_json_embeddings(content, file)
    data = JSON.parse(content.force_encoding('UTF-8'))
    
    # Handle array of objects
    if data.is_a?(Array)
      data.each_with_index do |item, index|
        text_content = extract_text_from_json(item)
        next if text_content.blank?
        
        VectorEmbedding.create!(
          content: text_content,
          content_type: 'dataset_json',
          namespace: "dataset_#{id}",
          metadata: {
            dataset_id: id,
            file_name: file.filename.to_s,
            item_index: index,
            source_type: 'ai_dataset',
            original_data: item
          },
          workspace: workspace,
          embedding: generate_embedding_vector(text_content)
        )
      end
    else
      # Handle single object
      text_content = extract_text_from_json(data)
      if text_content.present?
        VectorEmbedding.create!(
          content: text_content,
          content_type: 'dataset_json',
          namespace: "dataset_#{id}",
          metadata: {
            dataset_id: id,
            file_name: file.filename.to_s,
            source_type: 'ai_dataset',
            original_data: data
          },
          workspace: workspace,
          embedding: generate_embedding_vector(text_content)
        )
      end
    end
  end

  def split_text_into_chunks(text, chunk_size: 1000, overlap: 200)
    chunks = []
    start = 0
    
    while start < text.length
      end_pos = [start + chunk_size, text.length].min
      
      # Try to break on word boundaries
      if end_pos < text.length
        last_space = text.rindex(' ', end_pos)
        end_pos = last_space if last_space && last_space > start + chunk_size - 100
      end
      
      chunk = text[start...end_pos].strip
      chunks << chunk if chunk.present?
      
      start = end_pos - overlap
      start = end_pos if start <= 0
    end
    
    chunks
  end

  def extract_text_from_json(data)
    case data
    when Hash
      # Extract text from common fields
      text_fields = %w[text content description title body message]
      text_values = text_fields.map { |field| data[field] }.compact
      text_values.join(' ')
    when String
      data
    else
      data.to_s
    end
  end

  def generate_embedding_vector(text)
    # Placeholder for actual embedding generation
    # In a real implementation, this would call OpenAI embeddings API
    # For now, return a random vector of the expected dimension
    Array.new(1536) { rand(-1.0..1.0) }
  end
end