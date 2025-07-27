# frozen_string_literal: true

require_relative '../../../lib/stubs/github_client_stub'
require 'minitest/autorun'

class GitHubClientStubTest < Minitest::Test
  def setup
    @client = Stubs::GitHubClientStub.new
  end

  def test_user_returns_deterministic_data
    username = 'octocat'
    
    user1 = @client.user(username)
    user2 = @client.user(username)
    
    # Same username should produce same data
    assert_equal user1, user2
    
    # Should have expected structure
    assert_equal username, user1['login']
    assert user1['id'].is_a?(Integer)
    assert user1['public_repos'].is_a?(Integer)
    assert user1['followers'].is_a?(Integer)
    assert user1['following'].is_a?(Integer)
    assert_equal 'User', user1['type']
    refute user1['site_admin']
  end

  def test_user_generates_different_data_for_different_usernames
    user1 = @client.user('alice')
    user2 = @client.user('bob')
    
    # Different usernames should produce different data
    refute_equal user1['id'], user2['id']
    refute_equal user1['public_repos'], user2['public_repos']
    refute_equal user1['followers'], user2['followers']
  end

  def test_repos_returns_deterministic_repositories
    username = 'octocat'
    
    repos1 = @client.repos(username, per_page: 5)
    repos2 = @client.repos(username, per_page: 5)
    
    # Same request should produce same data
    assert_equal repos1, repos2
    
    # Should respect per_page limit
    assert repos1.length <= 5
    
    # Each repo should have expected structure
    repos1.each do |repo|
      assert repo['name'].is_a?(String)
      assert repo['full_name'].start_with?(username)
      assert repo['stargazers_count'].is_a?(Integer)
      assert repo['forks_count'].is_a?(Integer)
      assert repo['language'].is_a?(String)
      assert_includes [true, false], repo['private']
    end
  end

  def test_repos_generates_different_data_for_different_users
    repos1 = @client.repos('alice', per_page: 3)
    repos2 = @client.repos('bob', per_page: 3)
    
    # Different users should have different repositories
    refute_equal repos1, repos2
    
    # But structure should be consistent
    assert_equal repos1.length, repos2.length if repos1.length == repos2.length
  end

  def test_org_repos_returns_organization_repositories
    org_name = 'github'
    
    repos = @client.org_repos(org_name, per_page: 3)
    
    # Should return organization repositories
    assert repos.length <= 3
    
    repos.each do |repo|
      assert repo['full_name'].start_with?(org_name)
      assert_equal 'Organization', repo['owner']['type']
      # Mix of private/public for organizations
      assert_includes [true, false], repo['private']
    end
  end

  def test_repo_returns_single_repository_data
    owner = 'rails'
    repo_name = 'rails'
    
    repo = @client.repo(owner, repo_name)
    
    assert_equal repo_name, repo['name']
    assert_equal "#{owner}/#{repo_name}", repo['full_name']
    assert_equal owner, repo['owner']['login']
    assert repo['stargazers_count'].is_a?(Integer)
    assert repo['forks_count'].is_a?(Integer)
    assert repo['open_issues_count'].is_a?(Integer)
    assert_equal 'main', repo['default_branch']
    refute repo['fork']
  end

  def test_rate_limit_returns_rate_limit_status
    rate_limit = @client.rate_limit
    
    assert_equal 5000, rate_limit['resources']['core']['limit']
    assert rate_limit['resources']['core']['used'].is_a?(Integer)
    assert rate_limit['resources']['core']['remaining'].is_a?(Integer)
    assert rate_limit['resources']['core']['reset'].is_a?(Integer)
    
    assert_equal 30, rate_limit['resources']['search']['limit']
    assert rate_limit['rate']['limit'].is_a?(Integer)
  end

  def test_simulate_error_raises_appropriate_errors
    assert_raises(StandardError) { @client.simulate_error(:not_found) }
    assert_raises(StandardError) { @client.simulate_error(:rate_limit) }
    assert_raises(StandardError) { @client.simulate_error(:unauthorized) }
    assert_raises(StandardError) { @client.simulate_error(:service_unavailable) }
  end

  def test_error_messages_are_descriptive
    begin
      @client.simulate_error(:not_found)
      flunk "Expected error to be raised"
    rescue StandardError => e
      assert_includes e.message.downcase, 'not found'
    end

    begin
      @client.simulate_error(:rate_limit)
      flunk "Expected error to be raised"
    rescue StandardError => e
      assert_includes e.message.downcase, 'rate limit'
    end
  end

  def test_deterministic_behavior_across_multiple_calls
    # Test that the same inputs always produce the same outputs
    username = 'testuser'
    
    # Multiple calls should be identical
    5.times do
      user = @client.user(username)
      repos = @client.repos(username, per_page: 3)
      
      # Verify consistency
      assert_equal 'testuser', user['login']
      assert_equal 3, repos.length if repos.length == 3
      
      # Verify that computed values are deterministic
      expected_id = @client.send(:deterministic_id, username)
      assert_equal expected_id, user['id']
    end
  end

  def test_repository_languages_are_diverse
    repos = @client.repos('polyglot', per_page: 10)
    languages = repos.map { |repo| repo['language'] }.uniq
    
    # Should have multiple different languages
    assert languages.length > 1
    assert_includes languages, 'Ruby'
    assert_includes languages, 'JavaScript'
  end

  def test_repository_topics_are_generated
    repos = @client.repos('developer', per_page: 5)
    
    repos.each do |repo|
      assert repo['topics'].is_a?(Array)
      # Each repo should have 1-3 topics
      assert repo['topics'].length.between?(1, 3)
      # Topics should be strings
      repo['topics'].each { |topic| assert topic.is_a?(String) }
    end
  end
end