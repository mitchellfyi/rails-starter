# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require 'stringio'

# Test the doctor command in a simplified manner
class DoctorFunctionalityTest < Minitest::Test
  def test_doctor_command_output_includes_all_checks
    # Create a temporary directory to run the test in
    Dir.mktmpdir do |temp_dir|
      Dir.chdir(temp_dir) do
        # Run the doctor command and capture output
        output = `#{File.join(__dir__, '..', 'bin', 'railsplan')} doctor 2>&1`
        
        # Check that all expected sections are present
        assert_includes output, '🏥 Running system diagnostics...'
        assert_includes output, 'Ruby version:'
        assert_includes output, 'Checking template structure:'
        assert_includes output, 'Checking environment variables:'
        assert_includes output, 'Checking API key configuration:'
        assert_includes output, 'Checking database migrations:'
        assert_includes output, 'Checking installed module integrity:'
        assert_includes output, '🏥 Diagnostics complete'
      end
    end
  end

  def test_doctor_command_validates_env_vars
    # Create a temporary directory to run the test in
    Dir.mktmpdir do |temp_dir|
      Dir.chdir(temp_dir) do
        # Run without required env vars
        output = `#{File.join(__dir__, '..', 'bin', 'railsplan')} doctor 2>&1`
        assert_includes output, 'Missing critical environment variables'
        
        # Run with required env vars set
        env_output = `SECRET_KEY_BASE=test DATABASE_URL=test REDIS_URL=test #{File.join(__dir__, '..', 'bin', 'railsplan')} doctor 2>&1`
        assert_includes env_output, 'Critical environment variables are set'
      end
    end
  end

  def test_doctor_command_validates_api_key_formats
    # Create a temporary directory to run the test in  
    Dir.mktmpdir do |temp_dir|
      Dir.chdir(temp_dir) do
        # Test with valid API key formats
        valid_output = `SECRET_KEY_BASE=test DATABASE_URL=test REDIS_URL=test OPENAI_API_KEY=sk-test STRIPE_SECRET_KEY=sk_test GITHUB_TOKEN=ghp_test #{File.join(__dir__, '..', 'bin', 'railsplan')} doctor 2>&1`
        assert_includes valid_output, 'API key formats appear valid'
        
        # Test with invalid API key formats
        invalid_output = `SECRET_KEY_BASE=test DATABASE_URL=test REDIS_URL=test OPENAI_API_KEY=invalid STRIPE_SECRET_KEY=invalid GITHUB_TOKEN=invalid #{File.join(__dir__, '..', 'bin', 'railsplan')} doctor 2>&1`
        assert_includes invalid_output, 'API key format appears invalid'
      end
    end
  end
end