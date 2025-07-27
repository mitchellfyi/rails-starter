#!/usr/bin/env ruby
# frozen_string_literal: true

# CMS Module Validation Script
# This script validates that the CMS module is properly structured and contains all necessary files

require 'pathname'

class CMSValidator
  def initialize
    @module_path = Pathname.new(__dir__)
    @errors = []
    @warnings = []
  end

  def validate!
    puts "🔍 Validating CMS module structure..."
    
    validate_required_files
    validate_models
    validate_controllers
    validate_views
    validate_assets
    validate_tests
    validate_install_script
    
    report_results
  end

  private

  def validate_required_files
    required_files = [
      'README.md',
      'install.rb',
      'app/models/post.rb',
      'app/models/page.rb',
      'app/models/category.rb',
      'app/models/tag.rb',
      'app/models/seo_metadata.rb'
    ]

    required_files.each do |file|
      unless (@module_path / file).exist?
        @errors << "Missing required file: #{file}"
      end
    end
  end

  def validate_models
    model_files = @module_path.glob('app/models/*.rb')
    
    if model_files.empty?
      @errors << "No model files found"
      return
    end

    model_files.each do |file|
      content = file.read
      
      # Check for basic Rails model structure
      unless content.include?('< ApplicationRecord')
        @warnings << "#{file.basename} may not be a proper Rails model"
      end
      
      # Check for validations
      unless content.include?('validates')
        @warnings << "#{file.basename} has no validations"
      end
    end
  end

  def validate_controllers
    controller_dirs = [
      'app/controllers',
      'app/controllers/admin/cms',
      'app/controllers/api/v1'
    ]

    controller_dirs.each do |dir|
      path = @module_path / dir
      unless path.exist? && path.directory?
        @errors << "Missing controller directory: #{dir}"
      end
    end

    # Check for key controllers
    key_controllers = [
      'app/controllers/blog_controller.rb',
      'app/controllers/pages_controller.rb',
      'app/controllers/admin/cms/posts_controller.rb'
    ]

    key_controllers.each do |controller|
      unless (@module_path / controller).exist?
        @errors << "Missing key controller: #{controller}"
      end
    end
  end

  def validate_views
    view_dirs = [
      'views/blog',
      'views/pages',
      'views/admin/cms'
    ]

    view_dirs.each do |dir|
      path = @module_path / dir
      unless path.exist? && path.directory?
        @errors << "Missing view directory: #{dir}"
      end
    end

    # Check for key views
    key_views = [
      'views/blog/index.html.erb',
      'views/blog/show.html.erb',
      'views/admin/cms/dashboard/index.html.erb'
    ]

    key_views.each do |view|
      unless (@module_path / view).exist?
        @errors << "Missing key view: #{view}"
      end
    end
  end

  def validate_assets
    asset_dirs = [
      'assets/stylesheets',
      'assets/javascripts'
    ]

    asset_dirs.each do |dir|
      path = @module_path / dir
      unless path.exist? && path.directory?
        @warnings << "Missing asset directory: #{dir}"
      end
    end
  end

  def validate_tests
    test_dirs = [
      'test/models',
      'test/controllers'
    ]

    test_dirs.each do |dir|
      path = @module_path / dir
      unless path.exist? && path.directory?
        @warnings << "Missing test directory: #{dir}"
      end
    end
  end

  def validate_install_script
    install_script = @module_path / 'install.rb'
    
    unless install_script.exist?
      @errors << "Missing install.rb script"
      return
    end

    content = install_script.read
    
    # Check for key installation steps
    required_steps = [
      'gem ',
      'after_bundle',
      'directory ',
      'route ',
      'rails_command'
    ]

    required_steps.each do |step|
      unless content.include?(step)
        @warnings << "Install script may be missing: #{step}"
      end
    end
  end

  def report_results
    puts "\n📊 Validation Results:"
    puts "=" * 50

    if @errors.empty? && @warnings.empty?
      puts "✅ All validations passed! CMS module looks good."
    else
      if @errors.any?
        puts "❌ Errors found:"
        @errors.each { |error| puts "  • #{error}" }
      end

      if @warnings.any?
        puts "\n⚠️  Warnings:"
        @warnings.each { |warning| puts "  • #{warning}" }
      end
    end

    puts "\n📈 Module Statistics:"
    puts "  Models: #{count_files('app/models/*.rb')}"
    puts "  Controllers: #{count_files('app/controllers/**/*.rb')}"
    puts "  Views: #{count_files('views/**/*.erb')}"
    puts "  Tests: #{count_files('test/**/*_test.rb')}"
    puts "  Total Files: #{count_all_files}"
    
    puts "\n🎯 Module appears #{@errors.empty? ? 'ready for production' : 'to need fixes'}!"
  end

  def count_files(pattern)
    @module_path.glob(pattern).count
  end

  def count_all_files
    @module_path.glob('**/*').select(&:file?).count
  end
end

# Run validation if script is executed directly
if __FILE__ == $0
  validator = CMSValidator.new
  validator.validate!
end