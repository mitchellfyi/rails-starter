# frozen_string_literal: true

module Mcp
  module Fetcher
    # Specialized fetcher for document analysis and summarization
    # Processes files and extracts key information for AI context enrichment
    #
    # Example:
    #   Mcp::Registry.register(:document_summary, Mcp::Fetcher::DocumentSummary)
    #   
    #   context.fetch(:document_summary,
    #     file_path: '/path/to/document.pdf',
    #     extract_keywords: true,
    #     max_summary_length: 500
    #   )
    class DocumentSummary < File
      def self.allowed_params
        [:file_path, :file_content, :file_type, :extract_keywords, :max_summary_length, 
         :include_metadata, :chunk_size, :language]
      end

      def self.required_params
        [] # Either file_path or file_content is required, but we'll validate in fetch
      end

      def self.required_param?(param)
        false # Custom validation in fetch method
      end

      def self.description
        "Analyzes documents and extracts summaries, keywords, and metadata"
      end

      def self.fetch(file_path: nil, file_content: nil, file_type: nil, extract_keywords: true, 
                     max_summary_length: 500, include_metadata: true, chunk_size: 1000, language: 'en', **)
        
        # Custom validation since we need either file_path or file_content
        unless file_path.present? || file_content.present?
          raise ArgumentError, "Either file_path or file_content must be provided"
        end

        validate_all_params!(
          file_path: file_path, file_content: file_content, file_type: file_type,
          extract_keywords: extract_keywords, max_summary_length: max_summary_length,
          include_metadata: include_metadata, chunk_size: chunk_size, language: language
        )

        # Get file content if not provided
        content = file_content || read_file_content(file_path)
        detected_type = file_type || detect_file_type(file_path, content)

        # Process the document
        result = {
          file_path: file_path,
          file_type: detected_type,
          processed_at: Time.current
        }

        begin
          # Extract text content based on file type
          text_content = extract_text_content(content, detected_type)
          
          # Generate summary
          summary = generate_summary(text_content, max_summary_length)
          result[:summary] = summary

          # Extract keywords if requested
          if extract_keywords
            keywords = extract_keywords_from_text(text_content)
            result[:keywords] = keywords
          end

          # Add metadata if requested
          if include_metadata
            metadata = extract_document_metadata(text_content, detected_type)
            result[:metadata] = metadata
          end

          # Split into chunks for semantic processing
          if chunk_size > 0
            chunks = create_text_chunks(text_content, chunk_size)
            result[:chunks] = chunks
          end

          result[:success] = true
          result[:content_length] = text_content.length
          result[:word_count] = text_content.split.size

        rescue => e
          Rails.logger.error("DocumentSummary: Failed to process document: #{e.message}")
          result.merge!(
            success: false,
            error: e.message,
            summary: "Document processing failed",
            keywords: [],
            metadata: {}
          )
        end

        result
      end

      def self.fallback_data(file_path: nil, **)
        {
          file_path: file_path,
          file_type: 'unknown',
          success: false,
          error: "Document processing not available",
          summary: "Unable to process document",
          keywords: [],
          metadata: {},
          content_length: 0,
          word_count: 0,
          processed_at: Time.current
        }
      end

      private

      def self.read_file_content(file_path)
        return nil unless file_path && ::File.exist?(file_path)
        
        ::File.read(file_path)
      rescue => e
        Rails.logger.error("DocumentSummary: Cannot read file #{file_path}: #{e.message}")
        nil
      end

      def self.detect_file_type(file_path, content)
        return 'unknown' unless file_path || content

        if file_path
          extension = ::File.extname(file_path).downcase
          case extension
          when '.txt' then 'text/plain'
          when '.md' then 'text/markdown'
          when '.html' then 'text/html'
          when '.pdf' then 'application/pdf'
          when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          when '.json' then 'application/json'
          else 'text/plain'
          end
        else
          # Basic content detection
          if content.start_with?('%PDF')
            'application/pdf'
          elsif content.include?('<html') || content.include?('<HTML')
            'text/html'
          elsif content.start_with?('{') || content.start_with?('[')
            'application/json'
          else
            'text/plain'
          end
        end
      end

      def self.extract_text_content(content, file_type)
        return '' unless content

        case file_type
        when 'text/plain', 'text/markdown'
          content
        when 'text/html'
          extract_text_from_html(content)
        when 'application/json'
          extract_readable_from_json(content)
        when 'application/pdf'
          # For PDF, we'd need a gem like pdf-reader or poppler
          # For now, return placeholder
          "PDF content extraction requires additional setup. Content length: #{content.length} bytes"
        else
          # Attempt to treat as plain text
          content.force_encoding('UTF-8').scrub
        end
      end

      def self.extract_text_from_html(html_content)
        # Simple HTML tag removal - in production, use nokogiri or similar
        html_content.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
      end

      def self.extract_readable_from_json(json_content)
        parsed = JSON.parse(json_content)
        # Extract text values from JSON structure
        extract_text_from_hash(parsed).join(' ')
      rescue JSON::ParserError
        json_content
      end

      def self.extract_text_from_hash(obj)
        case obj
        when Hash
          obj.values.flat_map { |v| extract_text_from_hash(v) }
        when Array
          obj.flat_map { |item| extract_text_from_hash(item) }
        when String
          [obj]
        else
          [obj.to_s]
        end
      end

      def self.generate_summary(text, max_length)
        return '' if text.blank?

        # Simple extractive summarization - take first sentences up to max_length
        sentences = text.split(/[.!?]+/).map(&:strip).reject(&:blank?)
        
        summary = ''
        sentences.each do |sentence|
          if (summary + sentence).length <= max_length
            summary += sentence + '. '
          else
            break
          end
        end

        summary.strip
      end

      def self.extract_keywords_from_text(text)
        return [] if text.blank?

        # Simple keyword extraction - most frequent meaningful words
        words = text.downcase
                   .gsub(/[^\w\s]/, '')
                   .split
                   .reject { |word| word.length < 4 || stop_words.include?(word) }

        word_freq = words.tally
        word_freq.sort_by { |_, count| -count }.first(10).map(&:first)
      end

      def self.extract_document_metadata(text, file_type)
        {
          file_type: file_type,
          character_count: text.length,
          word_count: text.split.size,
          sentence_count: text.split(/[.!?]+/).size,
          paragraph_count: text.split(/\n\s*\n/).size,
          reading_time_minutes: (text.split.size / 200.0).ceil,
          language: detect_language(text)
        }
      end

      def self.create_text_chunks(text, chunk_size)
        return [] if text.blank?

        chunks = []
        words = text.split
        
        words.each_slice(chunk_size / 5) do |word_chunk| # Approximate words per chunk
          chunk_text = word_chunk.join(' ')
          chunks << {
            text: chunk_text,
            word_count: word_chunk.size,
            character_count: chunk_text.length
          }
        end

        chunks
      end

      def self.detect_language(text)
        # Simple language detection - could be enhanced with gems like whatlanguage
        return 'en' if text.blank?

        # Basic heuristics for common languages
        if text.match?(/\b(the|and|or|but|in|on|at|to|for|of|with|by)\b/i)
          'en'
        elsif text.match?(/\b(el|la|de|en|y|o|pero|con|por|para)\b/i)
          'es'
        elsif text.match?(/\b(le|la|de|en|et|ou|mais|avec|par|pour)\b/i)
          'fr'
        else
          'unknown'
        end
      end

      def self.stop_words
        %w[
          the and or but in on at to for of with by from up about into over after
          is are was were be been being have has had do does did will would could
          should can may might must shall this that these those a an some any all
          each every no not only also just even still already yet again more most
          much many little few less least very too so such how what where when why
          who which whom whose
        ]
      end
    end
  end
end