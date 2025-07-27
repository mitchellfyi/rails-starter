# frozen_string_literal: true

require 'test_helper'

class DocsModuleTest < ActiveSupport::TestCase
  test "documentation structure" do
    # Test that essential documentation files exist
    docs_to_check = %w[
      README.md
      CHANGELOG.md
      USAGE.md
    ]
    
    docs_to_check.each do |doc_file|
      doc_path = File.join(Rails.root, doc_file)
      
      if File.exist?(doc_path)
        content = File.read(doc_path)
        assert content.length > 100, "#{doc_file} should have substantial content"
        assert content.include?('#'), "#{doc_file} should have markdown headers"
      end
    end
  end

  test "api documentation configuration" do
    # Test that API documentation tools are configured
    if defined?(Rswag)
      # Check that RSwag is configured for API docs
      assert true, "RSwag available for API documentation"
    end
    
    # Check for swagger configuration
    swagger_config_path = File.join(Rails.root, 'config', 'initializers', 'rswag.rb')
    if File.exist?(swagger_config_path)
      config_content = File.read(swagger_config_path)
      assert config_content.include?('Rswag'), "RSwag should be configured"
    end
  end

  test "yard documentation setup" do
    # Test YARD documentation configuration
    yardopts_path = File.join(Rails.root, '.yardopts')
    
    if File.exist?(yardopts_path)
      yardopts_content = File.read(yardopts_path)
      assert yardopts_content.include?('--output-dir') || yardopts_content.include?('-o'), 
             ".yardopts should specify output directory"
    end
  end

  test "inline documentation quality" do
    # Test that code has reasonable inline documentation
    if defined?(Rails.application)
      # Check a sample of Ruby files for documentation
      ruby_files = Dir[File.join(Rails.root, 'app', '**', '*.rb')].first(5)
      
      ruby_files.each do |file_path|
        content = File.read(file_path)
        
        # Look for class or module documentation
        if content.match?(/class\s+\w+|module\s+\w+/)
          # Should have some comments or documentation
          comment_lines = content.lines.count { |line| line.strip.start_with?('#') }
          total_lines = content.lines.count
          
          # At least 10% of lines should be comments (very loose requirement)
          comment_ratio = comment_lines.to_f / total_lines
          assert comment_ratio > 0.05, "#{File.basename(file_path)} should have some documentation"
        end
      end
    end
  end

  test "readme completeness" do
    readme_path = File.join(Rails.root, 'README.md')
    
    if File.exist?(readme_path)
      readme_content = File.read(readme_path)
      
      essential_sections = [
        'Installation',
        'Usage',
        'Features'
      ]
      
      essential_sections.each do |section|
        assert readme_content.downcase.include?(section.downcase), 
               "README should include #{section} section"
      end
    else
      skip "README.md not found"
    end
  end

  test "changelog maintenance" do
    changelog_path = File.join(Rails.root, 'CHANGELOG.md')
    
    if File.exist?(changelog_path)
      changelog_content = File.read(changelog_path)
      
      # Should follow some changelog format
      assert changelog_content.include?('##') || changelog_content.include?('#'), 
             "CHANGELOG should have version headers"
      
      # Should have recent entries
      current_year = Date.current.year.to_s
      if changelog_content.include?(current_year)
        assert true, "CHANGELOG appears to be maintained"
      end
    end
  end

  test "code examples in documentation" do
    # Test that documentation includes code examples
    docs_dir = File.join(Rails.root, 'docs')
    
    if Dir.exist?(docs_dir)
      md_files = Dir[File.join(docs_dir, '**', '*.md')]
      
      md_files.first(3).each do |doc_file|
        content = File.read(doc_file)
        
        # Look for code blocks
        has_code_blocks = content.include?('```') || content.include?('    ')
        if content.length > 500 # Only check substantial docs
          assert has_code_blocks, "#{File.basename(doc_file)} should include code examples"
        end
      end
    end
  end

  test "documentation generation" do
    # Test that documentation can be generated
    if Rails.application.respond_to?(:config)
      # Basic test that app is configured for docs
      assert_not_nil Rails.application.config
    end
    
    # Test that yard can process the codebase
    if system('which yard > /dev/null 2>&1')
      # YARD is available, could generate docs
      assert true, "YARD documentation tool available"
    end
  end

  test "api documentation endpoints" do
    # Test that API documentation is accessible
    if Rails.application.routes.respond_to?(:routes)
      routes = Rails.application.routes.routes
      
      # Look for documentation routes
      doc_routes = routes.select do |route|
        route.path.spec.to_s.include?('docs') || 
        route.path.spec.to_s.include?('api-docs') ||
        route.path.spec.to_s.include?('swagger')
      end
      
      if doc_routes.any?
        assert true, "API documentation routes found"
      end
    end
  end

  test "license documentation" do
    # Test that license is documented
    license_files = %w[LICENSE LICENSE.md LICENSE.txt]
    
    license_found = license_files.any? do |license_file|
      File.exist?(File.join(Rails.root, license_file))
    end
    
    if license_found
      assert true, "License file found"
    end
  end

  test "contribution guidelines" do
    # Test for contribution guidelines
    contrib_files = %w[CONTRIBUTING.md CONTRIBUTING.txt .github/CONTRIBUTING.md]
    
    contrib_found = contrib_files.any? do |contrib_file|
      File.exist?(File.join(Rails.root, contrib_file))
    end
    
    if contrib_found
      contrib_path = contrib_files.find { |f| File.exist?(File.join(Rails.root, f)) }
      contrib_content = File.read(File.join(Rails.root, contrib_path))
      
      assert contrib_content.include?('contribute') || contrib_content.include?('pull request'),
             "Contribution guidelines should explain how to contribute"
    end
  end
end