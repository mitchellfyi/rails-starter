# frozen_string_literal: true

module Mcp
  module Fetcher
    # File fetcher for parsing documents, extracting text, and creating embeddings
    # for semantic search and context enrichment.
    #
    # Example:
    #   # Register for file processing
    #   Mcp::Registry.register(:parse_document, Mcp::Fetcher::File)
    #
    #   # Use in context
    #   context.fetch(:parse_document,
    #     file_path: '/path/to/document.pdf',
    #     chunk_size: 1000,
    #     create_embeddings: true,
    #     extract_metadata: true
    #   )
    class File < Base
      def self.allowed_params
        [:file_path, :file_content, :file_type, :chunk_size, :chunk_overlap, 
         :create_embeddings, :extract_metadata, :encoding, :user, :workspace]
      end

      def self.required_params
        [] # Either file_path or file_content is required, handled in validation
      end

      def self.required_param?(param)
        false # Custom validation in fetch method
      end

      def self.description
        "Parses documents, extracts text, and creates embeddings for semantic search"
      end

      def self.fetch(file_path: nil, file_content: nil, file_type: nil, chunk_size: 1000,
                     chunk_overlap: 200, create_embeddings: false, extract_metadata: true,
                     encoding: 'utf-8', user: nil, workspace: nil, **)
        
        # Custom validation - need either file_path or file_content
        if file_path.blank? && file_content.blank?
          raise ArgumentError, "Either file_path or file_content must be provided"
        end

        validate_all_params!(
          file_path: file_path, file_content: file_content, file_type: file_type,
          chunk_size: chunk_size, chunk_overlap: chunk_overlap, create_embeddings: create_embeddings,
          extract_metadata: extract_metadata, encoding: encoding, user: user, workspace: workspace
        )

        # Get file content and metadata
        content, metadata = if file_path
                             read_file_content(file_path, file_type, encoding, extract_metadata)
                           else
                             [file_content, { size: file_content.bytesize }]
                           end

        # Detect file type if not provided
        file_type ||= detect_file_type(file_path, content)

        # Parse content based on file type
        parsed_content = parse_content(content, file_type)

        # Create text chunks
        chunks = create_chunks(parsed_content, chunk_size, chunk_overlap)

        # Create embeddings if requested
        embeddings = create_embeddings ? generate_embeddings(chunks) : []

        # Store in database if persistence is needed
        file_record = store_file_record(file_path, parsed_content, chunks, embeddings, metadata, user, workspace) if user

        {
          file_path: file_path,
          file_type: file_type,
          metadata: metadata,
          content: parsed_content,
          chunks: chunks.map.with_index { |chunk, i| 
            { 
              index: i, 
              text: chunk, 
              embedding: embeddings[i] 
            } 
          },
          chunk_count: chunks.size,
          total_length: parsed_content.length,
          has_embeddings: create_embeddings,
          file_record_id: file_record&.id
        }
      end

      def self.fallback_data(file_path: nil, **)
        {
          file_path: file_path,
          file_type: 'unknown',
          metadata: {},
          content: '',
          chunks: [],
          chunk_count: 0,
          total_length: 0,
          has_embeddings: false,
          error: 'Failed to parse file'
        }
      end

      private

      # Read file content from disk
      def self.read_file_content(file_path, file_type, encoding, extract_metadata)
        unless ::File.exist?(file_path)
          raise ArgumentError, "File not found: #{file_path}"
        end

        # Extract metadata
        metadata = {}
        if extract_metadata
          file_stat = ::File.stat(file_path)
          metadata = {
            size: file_stat.size,
            modified_at: file_stat.mtime,
            created_at: file_stat.ctime,
            filename: ::File.basename(file_path),
            extension: ::File.extname(file_path)
          }
        end

        # Read content based on file type
        content = case file_type&.downcase
                 when 'pdf'
                   extract_pdf_text(file_path)
                 when 'docx', 'doc'
                   extract_word_text(file_path)
                 when 'txt', 'md', 'markdown'
                   ::File.read(file_path, encoding: encoding)
                 else
                   # Try reading as text first
                   begin
                     ::File.read(file_path, encoding: encoding)
                   rescue Encoding::InvalidByteSequenceError
                     # Try reading as binary and converting
                     ::File.read(file_path, mode: 'rb').force_encoding(encoding)
                   end
                 end

        [content, metadata]
      end

      # Detect file type from path or content
      def self.detect_file_type(file_path, content)
        if file_path
          extension = ::File.extname(file_path).downcase.delete('.')
          return extension unless extension.empty?
        end

        # Try to detect from content
        if content.start_with?('%PDF')
          'pdf'
        elsif content.start_with?('PK') # ZIP-based formats like DOCX
          'docx'
        else
          'txt'
        end
      end

      # Parse content based on file type
      def self.parse_content(content, file_type)
        case file_type&.downcase
        when 'pdf', 'docx', 'doc'
          # Content already extracted in read_file_content
          content
        when 'md', 'markdown'
          # Strip markdown formatting for plain text
          strip_markdown(content)
        when 'html', 'htm'
          strip_html(content)
        else
          content
        end
      end

      # Create text chunks with overlap
      def self.create_chunks(text, chunk_size, chunk_overlap)
        return [] if text.blank?

        chunks = []
        start_pos = 0

        while start_pos < text.length
          end_pos = start_pos + chunk_size
          
          # Try to break at sentence or word boundary
          if end_pos < text.length
            # Look for sentence boundary
            sentence_end = text.rindex(/[.!?]\s+/, end_pos)
            if sentence_end && sentence_end > start_pos + (chunk_size * 0.5)
              end_pos = sentence_end + 1
            else
              # Look for word boundary
              word_end = text.rindex(/\s/, end_pos)
              end_pos = word_end if word_end && word_end > start_pos + (chunk_size * 0.5)
            end
          end

          chunk = text[start_pos...end_pos].strip
          chunks << chunk if chunk.present?

          start_pos = end_pos - chunk_overlap
          break if start_pos >= text.length
        end

        chunks
      end

      # Generate embeddings for text chunks (stub - would integrate with actual embedding service)
      def self.generate_embeddings(chunks)
        # This would integrate with OpenAI embeddings API or similar service
        # For now, return empty arrays as placeholders
        Rails.logger.info("MCP File: Would generate embeddings for #{chunks.size} chunks")
        chunks.map { [] } # Placeholder empty vectors
      end

      # Store file record in database for future reference
      def self.store_file_record(file_path, content, chunks, embeddings, metadata, user, workspace)
        # This would create a database record to store the parsed file
        # Return nil for now since we don't have the model defined
        Rails.logger.info("MCP File: Would store file record for #{file_path}")
        nil
      end

      # Extract text from PDF files (would use gem like 'pdf-reader')
      def self.extract_pdf_text(file_path)
        Rails.logger.warn("MCP File: PDF extraction not implemented, treating as binary")
        "PDF content extraction not implemented for #{file_path}"
      end

      # Extract text from Word documents (would use gem like 'docx' or 'yomu')
      def self.extract_word_text(file_path)
        Rails.logger.warn("MCP File: Word document extraction not implemented, treating as binary")
        "Word document extraction not implemented for #{file_path}"
      end

      # Strip markdown formatting to get plain text
      def self.strip_markdown(text)
        text.gsub(/^\#{1,6}\s+/, '')      # Headers
            .gsub(/\*\*(.*?)\*\*/, '\1')  # Bold
            .gsub(/\*(.*?)\*/, '\1')      # Italic
            .gsub(/`(.*?)`/, '\1')        # Code
            .gsub(/^\s*[-*+]\s+/, '')     # Lists
            .gsub(/^\s*\d+\.\s+/, '')     # Numbered lists
            .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1') # Links
      end

      # Strip HTML tags to get plain text
      def self.strip_html(text)
        text.gsub(/<[^>]*>/, '')
            .gsub(/&lt;/, '<')
            .gsub(/&gt;/, '>')
            .gsub(/&amp;/, '&')
            .gsub(/&quot;/, '"')
            .gsub(/&#39;/, "'")
      end
    end
  end
end