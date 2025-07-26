# frozen_string_literal: true

require 'test_helper'

class Mcp::Fetcher::DocumentSummaryTest < ActiveSupport::TestCase
  def setup
    @sample_text = <<~TEXT
      This is a sample document for testing the document summary fetcher.
      It contains multiple sentences and paragraphs to test the summarization
      and keyword extraction functionality.
      
      The document discusses various topics including technology, artificial
      intelligence, and software development. These are important concepts
      in modern computing and data analysis.
      
      In conclusion, this document serves as a comprehensive example for
      testing purposes and demonstrates the capabilities of the MCP system.
    TEXT

    @temp_file = '/tmp/test_document.txt'
    File.write(@temp_file, @sample_text)
  end

  def teardown
    File.delete(@temp_file) if File.exist?(@temp_file)
  end

  test "processes document from file path" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_path: @temp_file,
      max_summary_length: 200,
      extract_keywords: true
    )

    assert result[:success]
    assert_equal @temp_file, result[:file_path]
    assert_equal 'text/plain', result[:file_type]
    assert result[:summary].present?
    assert result[:keywords].is_a?(Array)
    assert result[:metadata]
    assert result[:content_length] > 0
    assert result[:word_count] > 0
  end

  test "processes document from content string" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      file_type: 'text/plain',
      max_summary_length: 150
    )

    assert result[:success]
    assert_equal 'text/plain', result[:file_type]
    assert result[:summary].length <= 150
    assert_equal @sample_text.length, result[:content_length]
  end

  test "extracts keywords from text" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      extract_keywords: true
    )

    keywords = result[:keywords]
    assert keywords.include?('document')
    assert keywords.include?('testing')
    assert keywords.include?('technology')
    # Should not include stop words
    assert_not keywords.include?('this')
    assert_not keywords.include?('with')
  end

  test "generates document metadata" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      include_metadata: true
    )

    metadata = result[:metadata]
    assert_equal 'text/plain', metadata[:file_type]
    assert metadata[:character_count] > 0
    assert metadata[:word_count] > 0
    assert metadata[:sentence_count] > 0
    assert metadata[:paragraph_count] >= 1
    assert metadata[:reading_time_minutes] > 0
    assert_equal 'en', metadata[:language]
  end

  test "creates text chunks when requested" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      chunk_size: 100
    )

    assert result[:chunks].is_a?(Array)
    assert result[:chunks].size > 0
    
    first_chunk = result[:chunks].first
    assert first_chunk[:text].present?
    assert first_chunk[:word_count] > 0
    assert first_chunk[:character_count] > 0
  end

  test "detects file type from extension" do
    md_file = '/tmp/test.md'
    File.write(md_file, "# Markdown Content\n\nThis is markdown.")

    result = Mcp::Fetcher::DocumentSummary.fetch(file_path: md_file)

    assert_equal 'text/markdown', result[:file_type]

    File.delete(md_file)
  end

  test "detects file type from content" do
    html_content = "<html><body><h1>Test</h1><p>HTML content</p></body></html>"
    
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: html_content
    )

    assert_equal 'text/html', result[:file_type]
  end

  test "extracts text from HTML content" do
    html_content = "<html><body><h1>Title</h1><p>This is a paragraph.</p></body></html>"
    
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: html_content,
      file_type: 'text/html'
    )

    assert result[:success]
    # Should extract text without HTML tags
    assert_not_includes result[:summary], '<h1>'
    assert_not_includes result[:summary], '<p>'
    assert_includes result[:summary], 'Title'
    assert_includes result[:summary], 'paragraph'
  end

  test "processes JSON content" do
    json_content = {
      title: "Test Document",
      description: "This is a test document for JSON processing",
      content: "The main content of the document",
      tags: ["test", "json", "processing"]
    }.to_json

    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: json_content,
      file_type: 'application/json'
    )

    assert result[:success]
    # Should extract readable text from JSON values
    assert_includes result[:summary], 'Test Document'
    assert_includes result[:summary], 'test document'
  end

  test "handles PDF placeholder" do
    pdf_content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog"
    
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: pdf_content,
      file_type: 'application/pdf'
    )

    assert result[:success]
    assert_includes result[:summary], 'PDF content extraction requires'
  end

  test "validates required parameters" do
    assert_raises ArgumentError do
      Mcp::Fetcher::DocumentSummary.fetch(max_summary_length: 100)
    end
  end

  test "handles file read errors gracefully" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_path: '/nonexistent/file.txt'
    )

    assert_not result[:success]
    assert_includes result[:error], 'processing failed'
  end

  test "provides fallback data" do
    fallback = Mcp::Fetcher::DocumentSummary.fallback_data(
      file_path: @temp_file
    )

    assert_equal @temp_file, fallback[:file_path]
    assert_not fallback[:success]
    assert_includes fallback[:error], 'Document processing not available'
    assert_equal 'Unable to process document', fallback[:summary]
    assert_equal [], fallback[:keywords]
    assert_equal({}, fallback[:metadata])
  end

  test "limits summary to max length" do
    long_text = "This is a very long sentence. " * 50
    
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: long_text,
      max_summary_length: 100
    )

    assert result[:summary].length <= 100
  end

  test "detects language heuristically" do
    spanish_text = "Este es un documento en español con palabras como el, la, de, en, y, para."
    
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: spanish_text,
      include_metadata: true
    )

    assert_equal 'es', result[:metadata][:language]
  end

  test "skips keyword extraction when disabled" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      extract_keywords: false
    )

    assert_nil result[:keywords]
  end

  test "skips metadata when disabled" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      include_metadata: false
    )

    assert_nil result[:metadata]
  end

  test "skips chunking when chunk_size is 0" do
    result = Mcp::Fetcher::DocumentSummary.fetch(
      file_content: @sample_text,
      chunk_size: 0
    )

    assert_nil result[:chunks]
  end
end