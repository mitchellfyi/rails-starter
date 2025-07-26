# frozen_string_literal: true

require 'test_helper'
require 'webmock/test_unit'

class Mcp::Fetcher::GitHubInfoTest < ActiveSupport::TestCase
  include WebMock::API

  def setup
    WebMock.enable!
    @username = 'octocat'
    @github_token = 'fake_token'
    @github_api_base = 'https://api.github.com'
  end

  def teardown
    WebMock.disable!
  end

  test "fetches GitHub profile information" do
    profile_data = {
      'name' => 'The Octocat',
      'bio' => 'GitHub mascot',
      'location' => 'San Francisco',
      'company' => 'GitHub',
      'blog' => 'https://github.blog',
      'public_repos' => 8,
      'followers' => 4000,
      'following' => 9,
      'created_at' => '2011-01-25T18:44:36Z',
      'updated_at' => '2023-12-01T10:00:00Z'
    }

    stub_request(:get, "#{@github_api_base}/users/#{@username}")
      .with(headers: { 'Authorization' => "token #{@github_token}" })
      .to_return(
        status: 200,
        body: profile_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: @username,
      github_token: @github_token,
      include_repos: false
    )

    assert result[:success]
    assert_equal @username, result[:username]
    assert_equal 'The Octocat', result[:profile][:name]
    assert_equal 'GitHub mascot', result[:profile][:bio]
    assert_equal 8, result[:profile][:public_repos]
  end

  test "fetches GitHub repositories" do
    repos_data = [
      {
        'name' => 'Hello-World',
        'full_name' => 'octocat/Hello-World',
        'description' => 'My first repository on GitHub!',
        'language' => 'Ruby',
        'stargazers_count' => 1500,
        'forks_count' => 800,
        'open_issues_count' => 5,
        'private' => false,
        'updated_at' => '2023-12-01T10:00:00Z',
        'html_url' => 'https://github.com/octocat/Hello-World'
      },
      {
        'name' => 'Spoon-Knife',
        'full_name' => 'octocat/Spoon-Knife',
        'description' => 'This repo is for demonstration purposes only.',
        'language' => 'HTML',
        'stargazers_count' => 12000,
        'forks_count' => 143000,
        'open_issues_count' => 15,
        'private' => false,
        'updated_at' => '2023-11-30T15:30:00Z',
        'html_url' => 'https://github.com/octocat/Spoon-Knife'
      }
    ]

    stub_request(:get, "#{@github_api_base}/users/#{@username}/repos?sort=updated&per_page=10")
      .with(headers: { 'Authorization' => "token #{@github_token}" })
      .to_return(
        status: 200,
        body: repos_data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: @username,
      github_token: @github_token,
      include_profile: false,
      repo_limit: 10
    )

    assert result[:success]
    assert_equal 2, result[:repositories][:count]
    assert_equal 13500, result[:repositories][:summary][:total_stars]
    
    languages = result[:repositories][:summary][:languages]
    assert_equal 1, languages['Ruby']
    assert_equal 1, languages['HTML']
    
    first_repo = result[:repositories][:repositories].first
    assert_equal 'Hello-World', first_repo[:name]
    assert_equal 'Ruby', first_repo[:language]
    assert_equal 1500, first_repo[:stars]
  end

  test "fetches organization repositories" do
    org_name = 'github'
    
    stub_request(:get, "#{@github_api_base}/orgs/#{org_name}/repos?sort=updated&per_page=5")
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: @username,
      org_name: org_name,
      include_profile: false,
      repo_limit: 5
    )

    assert result[:success]
    assert_equal 0, result[:repositories][:count]
  end

  test "handles API authentication without token" do
    stub_request(:get, "#{@github_api_base}/users/#{@username}")
      .with(headers: { 'Accept' => 'application/vnd.github.v3+json' })
      .to_return(
        status: 200,
        body: { 'name' => 'Public User' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: @username,
      include_repos: false
    )

    assert result[:success]
    assert_equal 'Public User', result[:profile][:name]
  end

  test "handles API rate limiting" do
    stub_request(:get, "#{@github_api_base}/users/#{@username}")
      .to_return(
        status: 403,
        body: { 'message' => 'API rate limit exceeded' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(
      username: @username,
      github_token: @github_token
    )

    assert_not result[:success]
    assert_includes result[:error], '403'
  end

  test "handles user not found" do
    stub_request(:get, "#{@github_api_base}/users/nonexistent")
      .to_return(
        status: 404,
        body: { 'message' => 'Not Found' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(username: 'nonexistent')

    assert_not result[:success]
    assert_includes result[:error], '404'
  end

  test "validates required parameters" do
    assert_raises ArgumentError do
      Mcp::Fetcher::GitHubInfo.fetch(github_token: @github_token) # missing username
    end
  end

  test "provides fallback data" do
    fallback = Mcp::Fetcher::GitHubInfo.fallback_data(username: @username)

    assert_equal @username, fallback[:username]
    assert_not fallback[:success]
    assert_includes fallback[:error], "GitHub data not available"
    assert_nil fallback[:profile]
    assert_equal [], fallback[:repositories]
    assert fallback[:fallback]
  end

  test "includes both profile and repositories by default" do
    # Stub both API calls
    stub_request(:get, "#{@github_api_base}/users/#{@username}")
      .to_return(
        status: 200,
        body: { 'name' => 'Test User' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "#{@github_api_base}/users/#{@username}/repos?sort=updated&per_page=10")
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = Mcp::Fetcher::GitHubInfo.fetch(username: @username)

    assert result[:success]
    assert result[:profile]
    assert result[:repositories]
  end

  test "caches responses appropriately" do
    # This test would verify that caching is working, but WebMock makes it complex
    # In a real test, you'd verify the cache key generation and TTL
    skip "Caching test requires more complex setup with Redis mock"
  end
end