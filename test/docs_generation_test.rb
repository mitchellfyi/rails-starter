#!/usr/bin/env ruby
# frozen_string_literal: true

# Test for the docs generation functionality in bin/synth

class DocsGenerationTest
  def self.run_tests
    puts "🧪 Testing docs generation functionality..."
    
    errors = []
    
    # Test 1: Check docs command exists in help
    errors << test_docs_command_in_help
    
    # Test 2: Test docs generation creates files
    errors << test_docs_generation_creates_files
    
    # Test 3: Test upgrade regenerates docs
    errors << test_upgrade_regenerates_docs
    
    # Clean up errors
    errors.compact!
    
    if errors.empty?
      puts "✅ All docs generation tests passed"
      true
    else
      puts "❌ Docs generation test failures:"
      errors.each { |error| puts "  - #{error}" }
      false
    end
  end
  
  private
  
  def self.test_docs_command_in_help
    output = `cd #{Dir.pwd} && ./bin/synth help`
    
    unless output.include?("docs")
      return "docs command not found in help output"
    end
    
    unless output.include?("Generate documentation from installed modules")
      return "docs command description not found in help"
    end
    
    puts "  ✅ docs command properly listed in help"
    nil
  end
  
  def self.test_docs_generation_creates_files
    # Clean up from any previous runs
    docs_path = File.join(Dir.pwd, 'docs')
    
    # Run docs generation
    output = `cd #{Dir.pwd} && ./bin/synth docs 2>&1`
    
    unless File.exist?(File.join(docs_path, 'README.md'))
      return "Main README.md not generated"
    end
    
    unless Dir.exist?(File.join(docs_path, 'modules'))
      return "modules directory not created"
    end
    
    # Check that module docs were created for installed modules
    module_files = Dir.glob(File.join(docs_path, 'modules', '*.md'))
    if module_files.empty?
      return "No module documentation files generated"
    end
    
    unless output.include?("Documentation generated successfully")
      return "Success message not shown"
    end
    
    puts "  ✅ docs generation creates required files"
    nil
  end
  
  def self.test_upgrade_regenerates_docs
    # Remove the main README to test regeneration
    main_readme = File.join(Dir.pwd, 'docs', 'README.md')
    File.delete(main_readme) if File.exist?(main_readme)
    
    # Run upgrade which should regenerate docs
    output = `cd #{Dir.pwd} && ./bin/synth upgrade --yes --no-backup 2>&1`
    
    unless output.include?("Regenerating documentation after upgrade")
      return "Upgrade does not mention doc regeneration"
    end
    
    unless File.exist?(main_readme)
      return "README.md not regenerated after upgrade"
    end
    
    puts "  ✅ upgrade command regenerates documentation"
    nil
  end
end

# Run tests if called directly
if __FILE__ == $0
  DocsGenerationTest.run_tests
end