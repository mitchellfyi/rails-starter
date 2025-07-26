#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify domain architecture is properly implemented
# This test ensures that install scripts create the correct directory structure
# with models in /app/models and domain logic in /app/domains/

def test_modular_scaffold_generator_architecture
  # Test that the ModularScaffoldGenerator follows the correct architecture
  generator_file = File.read(File.join(__dir__, '../lib/generators/rails/modular_scaffold_generator.rb'))
  
  # Should generate models in central location, not in domains
  if generator_file.match?(/dir.*app\/domains.*models/)
    raise 'ModularScaffoldGenerator should not put models in domain directories'
  end
  
  unless generator_file.match?(/rails:model.*name.*attributes/)
    raise 'ModularScaffoldGenerator should generate models in central location'
  end
  
  # Should generate controllers in domains
  unless generator_file.match?(/domain_path.*app\/controllers/) || generator_file.match?(/app\/domains.*controllers/)
    raise 'ModularScaffoldGenerator should put controllers in domain directories'
  end
               
  puts "✅ ModularScaffoldGenerator follows correct architecture"
end

def test_domain_install_scripts_architecture
  domain_modules = %w[auth billing ai cms workspace notifications admin onboarding]
  
  domain_modules.each do |domain|
    install_script = File.join(__dir__, "../scaffold/lib/templates/synth/#{domain}/install.rb")
    next unless File.exist?(install_script)
    
    content = File.read(install_script)
    
    # Check that domain directories are created without models subdirectory
    if content.include?('mkdir')
      if content.match?(/mkdir.*app\/domains.*models/)
        raise "#{domain} install script should not create models in domain directory"
      end
      
      # Should create app/models or app/models/concerns for central models
      unless content.match?(/mkdir.*app\/models/)
        raise "#{domain} install script should ensure central models directory exists"
      end
    end
    
    # Check that models are created in central location
    if content.include?('create_file') && content.include?('models/')
      model_creations = content.scan(/create_file\s+['"]([^'"]+\.rb)['"]/)
      model_files = model_creations.flatten.select { |f| f.include?('models/') && f.include?('app/') && !f.include?('spec/') }
      
      model_files.each do |model_file|
        unless model_file.match?(/^app\/models\//)
          raise "#{domain}: Model #{model_file} should be in central app/models directory"
        end
        if model_file.match?(/app\/domains.*models/)
          raise "#{domain}: Model #{model_file} should not be in domain directory"
        end
      end
    end
    
    puts "✅ #{domain.capitalize} module follows correct architecture"
  end
end

def test_domain_directory_structure
  # Test the expected domain structure
  expected_domains = %w[auth billing ai cms workspace notifications]
  
  expected_domains.each do |domain|
    install_script = File.join(__dir__, "../scaffold/lib/templates/synth/#{domain}/install.rb")
    next unless File.exist?(install_script)
    
    content = File.read(install_script)
    
    # Should create controllers in domain
    if content.include?('mkdir') && content.include?('controllers')
      unless content.match?(/app\/domains\/#{domain}.*controllers/)
        raise "#{domain} should create controllers in domain directory"
      end
    end
    
    # Should create services in domain (if services are mentioned)
    if content.include?('services')
      if content.include?('mkdir') && !content.match?(/app\/domains\/#{domain}.*services/)
        raise "#{domain} should create services in domain directory"
      end
    end
    
    # Should create jobs in domain (if jobs are mentioned)  
    if content.include?('jobs')
      if content.include?('mkdir') && !content.match?(/app\/domains\/#{domain}.*jobs/)
        raise "#{domain} should create jobs in domain directory"
      end
    end
  end
  
  puts "✅ Domain directory structure is correct"
end

def test_documentation_exists
  doc_file = File.join(__dir__, '../docs/DOMAIN_ARCHITECTURE.md')
  unless File.exist?(doc_file)
    raise 'Domain architecture documentation should exist'
  end
  
  content = File.read(doc_file)
  unless content.match?(/models.*app\/models/) || content.match?(/\/app\/models/)
    raise 'Documentation should explain model location'
  end
  unless content.match?(/app\/domains/)
    raise 'Documentation should explain domain structure'
  end
  unless content.match?(/controllers/) && content.match?(/services/) && content.match?(/jobs/)
    raise 'Documentation should explain domain components'
  end
  
  puts "✅ Domain architecture documentation exists and is comprehensive"
end

def test_theme_and_testing_modules_appropriately_structured
  # Theme module should not have domain logic (only assets/JS)
  theme_install = File.join(__dir__, '../scaffold/lib/templates/synth/theme/install.rb')
  if File.exist?(theme_install)
    content = File.read(theme_install)
    if content.match?(/app\/domains.*controllers/)
      raise 'Theme module should not create controllers in domain directory'
    end
    if content.match?(/app\/domains.*models/)
      raise 'Theme module should not create models in domain directory'
    end
    puts "✅ Theme module is appropriately structured (assets only)"
  end
  
  # Testing module should organize test utilities in domains but not business logic
  testing_install = File.join(__dir__, '../scaffold/lib/templates/synth/testing/install.rb')
  if File.exist?(testing_install)
    content = File.read(testing_install)
    unless content.match?(/spec\/domains\/testing/)
      raise 'Testing module should organize test utilities in domains'
    end
    if content.match?(/app\/domains\/testing.*controllers/)
      raise 'Testing module should not create controllers'
    end
    puts "✅ Testing module is appropriately structured (test utilities only)"
  end
end

# Run the tests
if __FILE__ == $0
  puts "🧪 Testing Domain Architecture Implementation..."
  puts "=" * 60
  
  begin
    test_modular_scaffold_generator_architecture
    test_domain_install_scripts_architecture  
    test_domain_directory_structure
    test_documentation_exists
    test_theme_and_testing_modules_appropriately_structured
    
    puts "=" * 60
    puts "🎉 All domain architecture tests passed!"
    puts ""
    puts "✅ Models are correctly placed in /app/models"
    puts "✅ Domain logic is correctly organized in /app/domains/{domain}/"
    puts "✅ Install scripts follow the correct architecture"
    puts "✅ Documentation is comprehensive"
    
  rescue => e
    puts "❌ Domain architecture test failed: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end