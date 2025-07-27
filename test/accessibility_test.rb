#!/usr/bin/env ruby
# frozen_string_literal: true

# Accessibility compliance test for Rails SaaS Starter Template
# This script checks HTML files for basic accessibility standards

require 'fileutils'

class AccessibilityComplianceTest
  def initialize
    @template_root = File.expand_path('..', __dir__)
    @errors = []
    @warnings = []
  end

  def run
    puts "🔍 Checking Rails SaaS Starter Template for Accessibility Compliance..."
    puts "   Checking directory: #{@template_root}"
    
    check_html_files
    check_layout_files
    check_helper_files
    check_css_files
    
    report_results
  end

  private

  def check_html_files
    puts "\n📄 Checking HTML template files..."
    
    html_files = Dir.glob("#{@template_root}/app/views/**/*.html.erb")
    
    html_files.each do |file|
      check_file_accessibility(file)
    end
    
    puts "✅ Checked #{html_files.count} HTML template files"
  end

  def check_layout_files
    puts "\n🏗️  Checking layout files..."
    
    layout_files = Dir.glob("#{@template_root}/app/views/layouts/*.html.erb")
    
    layout_files.each do |file|
      check_layout_accessibility(file)
    end
    
    puts "✅ Checked #{layout_files.count} layout files"
  end

  def check_file_accessibility(file)
    content = File.read(file)
    filename = File.basename(file)
    
    # Check for proper heading hierarchy
    unless content.match?(/h[1-6]/)
      add_warning("#{filename}: No headings found - consider adding semantic headings")
    end
    
    # Check for images without alt text
    if content.match?(/<img(?![^>]*alt=)/) 
      add_error("#{filename}: Images found without alt attributes")
    end
    
    # Check for empty alt text
    if content.match?(/alt=""/) && !content.match?(/aria-hidden="true"/)
      add_warning("#{filename}: Empty alt text found - ensure decorative images are marked as aria-hidden")
    end
    
    # Check for proper form labels
    if content.match?(/<input/) && !content.match?(/label.*for=|aria-label/)
      add_warning("#{filename}: Form inputs may be missing proper labels")
    end
    
    # Check for semantic HTML
    semantic_tags = %w[main nav header footer section article aside]
    has_semantic = semantic_tags.any? { |tag| content.include?("<#{tag}") }
    unless has_semantic
      add_warning("#{filename}: Consider using semantic HTML elements (main, nav, header, etc.)")
    end
  end

  def check_layout_accessibility(file)
    content = File.read(file)
    filename = File.basename(file)
    
    # Check for lang attribute
    unless content.match?(/html.*lang=/)
      add_error("#{filename}: HTML element missing lang attribute")
    end
    
    # Check for skip links
    unless content.match?(/skip.*content|#main-content/)
      add_warning("#{filename}: Consider adding skip links for keyboard navigation")
    end
    
    # Check for proper title
    unless content.match?(/<title>/)
      add_error("#{filename}: Missing title element")
    end
    
    # Check for meta description
    unless content.match?(/meta.*name="description"/)
      add_warning("#{filename}: Missing meta description")
    end
    
    # Check for viewport meta tag
    unless content.match?(/meta.*name="viewport"/)
      add_error("#{filename}: Missing viewport meta tag")
    end
  end

  def check_helper_files
    puts "\n🛠️  Checking accessibility helper files..."
    
    helper_files = Dir.glob("#{@template_root}/app/helpers/*accessibility*.rb")
    
    if helper_files.empty?
      add_warning("No accessibility helper files found - consider creating accessibility utilities")
    else
      puts "✅ Found #{helper_files.count} accessibility helper file(s)"
      helper_files.each { |file| puts "   - #{File.basename(file)}" }
    end
  end

  def check_css_files
    puts "\n🎨 Checking CSS for accessibility..."
    
    css_files = Dir.glob("#{@template_root}/app/assets/stylesheets/**/*.{css,scss}")
    
    if css_files.any?
      css_files.each do |file|
        check_css_accessibility(file)
      end
    else
      puts "ℹ️  No CSS files found in app/assets/stylesheets"
    end
  end

  def check_css_accessibility(file)
    content = File.read(file)
    filename = File.basename(file)
    
    # Check for focus styles
    unless content.match?(/focus:|:focus/)
      add_warning("#{filename}: No focus styles found - ensure interactive elements have visible focus indicators")
    end
    
    # Check for screen reader only styles
    unless content.match?(/sr-only|screen-reader/)
      add_warning("#{filename}: No screen reader only styles found - consider adding .sr-only utility")
    end
  end

  def add_error(message)
    @errors << message
    puts "❌ #{message}"
  end

  def add_warning(message)
    @warnings << message
    puts "⚠️  #{message}"
  end

  def report_results
    puts "\n" + "="*60
    puts "ACCESSIBILITY COMPLIANCE REPORT"
    puts "="*60
    
    if @errors.empty? && @warnings.empty?
      puts "🎉 Excellent! No accessibility issues found."
    else
      if @errors.any?
        puts "\n❌ ERRORS (#{@errors.count}):"
        @errors.each { |error| puts "   • #{error}" }
      end
      
      if @warnings.any?
        puts "\n⚠️  WARNINGS (#{@warnings.count}):"
        @warnings.each { |warning| puts "   • #{warning}" }
      end
    end
    
    puts "\nSUMMARY:"
    puts "  Errors: #{@errors.count}"
    puts "  Warnings: #{@warnings.count}"
    puts "  Status: #{@errors.empty? ? '✅ PASS' : '❌ FAIL'}"
    
    exit(@errors.empty? ? 0 : 1)
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  AccessibilityComplianceTest.new.run
end