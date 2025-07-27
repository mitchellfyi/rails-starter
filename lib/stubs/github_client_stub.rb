# frozen_string_literal: true

require 'digest'

module Stubs
  # Stub client for GitHub API calls in test environment
  # Returns deterministic, predictable responses for testing
  class GitHubClientStub
    def initialize(access_token: nil)
      @access_token = access_token
    end

    # Get user information
    def user(username = nil)
      username ||= 'octocat'
      
      {
        'login' => username,
        'id' => deterministic_id(username),
        'node_id' => "MDQ6VXNlcjAwMDAwMDA=",
        'avatar_url' => "https://github.com/images/error/#{username}_happy.gif",
        'gravatar_id' => '',
        'url' => "https://api.github.com/users/#{username}",
        'html_url' => "https://github.com/#{username}",
        'name' => username.capitalize,
        'company' => "Test Company",
        'blog' => "https://#{username}.example.com",
        'location' => "Test Location",
        'email' => "#{username}@example.com",
        'bio' => "Test user for #{username} - deterministic response",
        'public_repos' => deterministic_count(username, 'repos'),
        'public_gists' => deterministic_count(username, 'gists'),
        'followers' => deterministic_count(username, 'followers'),
        'following' => deterministic_count(username, 'following'),
        'created_at' => '2023-01-01T00:00:00Z',
        'updated_at' => '2023-12-01T00:00:00Z',
        'type' => 'User',
        'site_admin' => false
      }
    end

    # Get user repositories
    def repos(username = nil, options = {})
      username ||= 'octocat'
      per_page = options[:per_page] || 30
      
      # Generate deterministic repositories
      repo_count = [deterministic_count(username, 'repos'), per_page].min
      
      (1..repo_count).map do |i|
        repo_name = "#{username}-repo-#{i}"
        {
          'id' => deterministic_id("#{username}-#{repo_name}"),
          'node_id' => "MDEwOlJlcG9zaXRvcnkwMDAwMDA=",
          'name' => repo_name,
          'full_name' => "#{username}/#{repo_name}",
          'owner' => {
            'login' => username,
            'id' => deterministic_id(username),
            'avatar_url' => "https://github.com/images/error/#{username}_happy.gif",
            'type' => 'User',
            'site_admin' => false
          },
          'private' => false,
          'html_url' => "https://github.com/#{username}/#{repo_name}",
          'description' => "Test repository #{i} for #{username} - deterministic response",
          'fork' => false,
          'url' => "https://api.github.com/repos/#{username}/#{repo_name}",
          'language' => determine_language(i),
          'stargazers_count' => deterministic_count("#{username}-#{repo_name}", 'stars'),
          'watchers_count' => deterministic_count("#{username}-#{repo_name}", 'watchers'),
          'forks_count' => deterministic_count("#{username}-#{repo_name}", 'forks'),
          'open_issues_count' => deterministic_count("#{username}-#{repo_name}", 'issues'),
          'default_branch' => 'main',
          'created_at' => '2023-01-01T00:00:00Z',
          'updated_at' => '2023-12-01T00:00:00Z',
          'pushed_at' => '2023-12-01T00:00:00Z',
          'size' => deterministic_count("#{username}-#{repo_name}", 'size'),
          'visibility' => 'public',
          'topics' => generate_topics(repo_name, i)
        }
      end
    end

    # Get organization repositories
    def org_repos(org_name, options = {})
      per_page = options[:per_page] || 30
      
      # Generate deterministic organization repositories
      repo_count = [deterministic_count(org_name, 'org-repos'), per_page].min
      
      (1..repo_count).map do |i|
        repo_name = "#{org_name}-project-#{i}"
        {
          'id' => deterministic_id("#{org_name}-#{repo_name}"),
          'node_id' => "MDEwOlJlcG9zaXRvcnkwMDAwMDA=",
          'name' => repo_name,
          'full_name' => "#{org_name}/#{repo_name}",
          'owner' => {
            'login' => org_name,
            'id' => deterministic_id(org_name),
            'avatar_url' => "https://github.com/images/error/#{org_name}_happy.gif",
            'type' => 'Organization',
            'site_admin' => false
          },
          'private' => i.even?, # Mix of private/public for testing
          'html_url' => "https://github.com/#{org_name}/#{repo_name}",
          'description' => "Organization project #{i} for #{org_name} - deterministic response",
          'fork' => false,
          'url' => "https://api.github.com/repos/#{org_name}/#{repo_name}",
          'language' => determine_language(i),
          'stargazers_count' => deterministic_count("#{org_name}-#{repo_name}", 'stars'),
          'watchers_count' => deterministic_count("#{org_name}-#{repo_name}", 'watchers'),
          'forks_count' => deterministic_count("#{org_name}-#{repo_name}", 'forks'),
          'open_issues_count' => deterministic_count("#{org_name}-#{repo_name}", 'issues'),
          'default_branch' => 'main',
          'created_at' => '2023-01-01T00:00:00Z',
          'updated_at' => '2023-12-01T00:00:00Z',
          'pushed_at' => '2023-12-01T00:00:00Z',
          'size' => deterministic_count("#{org_name}-#{repo_name}", 'size'),
          'visibility' => i.even? ? 'private' : 'public',
          'topics' => generate_topics(repo_name, i)
        }
      end
    end

    # Get repository information
    def repo(owner, repo_name)
      {
        'id' => deterministic_id("#{owner}-#{repo_name}"),
        'node_id' => "MDEwOlJlcG9zaXRvcnkwMDAwMDA=",
        'name' => repo_name,
        'full_name' => "#{owner}/#{repo_name}",
        'owner' => {
          'login' => owner,
          'id' => deterministic_id(owner),
          'avatar_url' => "https://github.com/images/error/#{owner}_happy.gif",
          'type' => 'User',
          'site_admin' => false
        },
        'private' => false,
        'html_url' => "https://github.com/#{owner}/#{repo_name}",
        'description' => "Test repository #{repo_name} owned by #{owner} - deterministic response",
        'fork' => false,
        'url' => "https://api.github.com/repos/#{owner}/#{repo_name}",
        'language' => determine_language(repo_name.length),
        'stargazers_count' => deterministic_count("#{owner}-#{repo_name}", 'stars'),
        'watchers_count' => deterministic_count("#{owner}-#{repo_name}", 'watchers'),
        'forks_count' => deterministic_count("#{owner}-#{repo_name}", 'forks'),
        'open_issues_count' => deterministic_count("#{owner}-#{repo_name}", 'issues'),
        'default_branch' => 'main',
        'created_at' => '2023-01-01T00:00:00Z',
        'updated_at' => '2023-12-01T00:00:00Z',
        'pushed_at' => '2023-12-01T00:00:00Z',
        'size' => deterministic_count("#{owner}-#{repo_name}", 'size'),
        'license' => {
          'key' => 'mit',
          'name' => 'MIT License',
          'spdx_id' => 'MIT'
        },
        'visibility' => 'public',
        'topics' => generate_topics(repo_name, repo_name.length)
      }
    end

    # Error simulation for testing error handling
    def simulate_error(error_type = :not_found)
      case error_type
      when :not_found
        raise StandardError, "Not Found"
      when :rate_limit
        raise StandardError, "API rate limit exceeded"
      when :unauthorized
        raise StandardError, "Bad credentials"
      when :service_unavailable
        raise StandardError, "GitHub service temporarily unavailable"
      else
        raise StandardError, "Unknown GitHub API error"
      end
    end

    # Check rate limiting status
    def rate_limit
      {
        'resources' => {
          'core' => {
            'limit' => 5000,
            'used' => 42,
            'remaining' => 4958,
            'reset' => (Time.now + 1.hour).to_i
          },
          'search' => {
            'limit' => 30,
            'used' => 0,
            'remaining' => 30,
            'reset' => (Time.now + 1.minute).to_i
          }
        },
        'rate' => {
          'limit' => 5000,
          'used' => 42,
          'remaining' => 4958,
          'reset' => (Time.now + 1.hour).to_i
        }
      }
    end

    private

    # Generate deterministic ID based on input
    def deterministic_id(input)
      Digest::MD5.hexdigest(input.to_s).to_i(16) % 1000000
    end

    # Generate deterministic count based on input and type
    def deterministic_count(input, count_type)
      hash = Digest::MD5.hexdigest("#{input}-#{count_type}").to_i(16)
      case count_type
      when 'repos'
        (hash % 50) + 1
      when 'followers', 'following'
        hash % 1000
      when 'stars', 'watchers'
        hash % 500
      when 'forks'
        hash % 100
      when 'issues'
        hash % 20
      when 'gists'
        hash % 30
      when 'size'
        hash % 10000
      when 'org-repos'
        (hash % 20) + 5
      else
        hash % 100
      end
    end

    # Determine language based on index
    def determine_language(index)
      languages = ['Ruby', 'JavaScript', 'Python', 'Go', 'Java', 'TypeScript', 'C++', 'C#', 'PHP', 'Swift']
      languages[index % languages.length]
    end

    # Generate topics for repository
    def generate_topics(repo_name, index)
      all_topics = ['web', 'api', 'framework', 'library', 'tool', 'cli', 'test', 'demo', 'example', 'tutorial']
      num_topics = (index % 3) + 1
      all_topics.take(num_topics)
    end
  end
end