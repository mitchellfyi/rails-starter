# frozen_string_literal: true

require_relative '../../../../../../lib/api_client_factory'

module Mcp
  module Fetcher
    # Specialized fetcher for retrieving GitHub repository and user information
    # Handles authentication and provides structured GitHub data for AI contexts
    #
    # Example:
    #   Mcp::Registry.register(:github_info, Mcp::Fetcher::GitHubInfo)
    #   
    #   context.fetch(:github_info, 
    #     username: 'octocat',
    #     github_token: ENV['GITHUB_TOKEN'],
    #     include_repos: true
    #   )
    class GitHubInfo < Http
      def self.allowed_params
        [:username, :github_token, :include_repos, :repo_limit, :include_profile, :org_name]
      end

      def self.required_params
        [:username]
      end

      def self.required_param?(param)
        required_params.include?(param)
      end

      def self.description
        "Fetches GitHub user profile and repository information"
      end

      def self.fetch(username:, github_token: nil, include_repos: true, repo_limit: 10, include_profile: true, org_name: nil, **)
        validate_all_params!(username: username, github_token: github_token, include_repos: include_repos, repo_limit: repo_limit, include_profile: include_profile, org_name: org_name)

        result = { username: username }
        headers = build_github_headers(github_token)

        begin
          # Fetch user profile
          if include_profile
            profile_data = fetch_github_profile(username, headers)
            result[:profile] = profile_data
          end

          # Fetch repositories
          if include_repos
            repos_data = fetch_github_repos(username, headers, repo_limit, org_name)
            result[:repositories] = repos_data
          end

          # Add metadata
          result.merge!(
            fetched_at: Time.current,
            success: true,
            api_rate_limit_remaining: nil # Could be extracted from response headers
          )

        rescue => e
          Rails.logger.error("GitHubInfo: Failed to fetch data for #{username}: #{e.message}")
          result.merge!(
            success: false,
            error: e.message,
            fallback: true
          )
        end

        result
      end

      def self.fallback_data(username: nil, **)
        {
          username: username,
          success: false,
          error: "GitHub data not available",
          profile: nil,
          repositories: [],
          fetched_at: Time.current,
          fallback: true
        }
      end

      private

      def self.build_github_headers(github_token)
        headers = {
          'Accept' => 'application/vnd.github.v3+json',
          'User-Agent' => 'Rails-MCP-Fetcher/1.0'
        }

        if github_token.present?
          headers['Authorization'] = "token #{github_token}"
        end

        headers
      end

      def self.fetch_github_profile(username, headers)
        # Use GitHub client from factory (stub in test, real in other environments)
        if ApiClientFactory.stub_mode?
          client = ApiClientFactory.github_client
          profile_data = client.user(username)
          
          {
            name: profile_data['name'],
            bio: profile_data['bio'],
            location: profile_data['location'],
            company: profile_data['company'],
            blog: profile_data['blog'],
            public_repos: profile_data['public_repos'],
            followers: profile_data['followers'],
            following: profile_data['following'],
            created_at: profile_data['created_at'],
            updated_at: profile_data['updated_at']
          }
        else
          # Original HTTP-based implementation for non-test environments
          url = "https://api.github.com/users/#{username}"
          
          response = super(
            url: url,
            headers: headers,
            cache_key: "github_profile_#{username}",
            cache_ttl: 1.hour,
            rate_limit_key: 'github_api'
          )

          if response[:success]
            profile = response[:data]
            {
              name: profile['name'],
              bio: profile['bio'],
              location: profile['location'],
              company: profile['company'],
              blog: profile['blog'],
              public_repos: profile['public_repos'],
              followers: profile['followers'],
              following: profile['following'],
              created_at: profile['created_at'],
              updated_at: profile['updated_at']
            }
          else
            nil
          end
        end
      end

      def self.fetch_github_repos(username, headers, limit, org_name)
        # Use GitHub client from factory (stub in test, real in other environments)
        if ApiClientFactory.stub_mode?
          client = ApiClientFactory.github_client
          
          # Get repositories based on whether it's for a user or organization
          repos_data = if org_name.present?
                         client.org_repos(org_name, per_page: limit)
                       else
                         client.repos(username, per_page: limit)
                       end
          
          # Transform to expected format
          repos = repos_data.map do |repo|
            {
              name: repo['name'],
              full_name: repo['full_name'],
              description: repo['description'],
              language: repo['language'],
              stars: repo['stargazers_count'],
              forks: repo['forks_count'],
              open_issues: repo['open_issues_count'],
              private: repo['private'],
              updated_at: repo['updated_at'],
              url: repo['html_url']
            }
          end

          {
            count: repos.size,
            repositories: repos,
            summary: {
              total_stars: repos.sum { |r| r[:stars] || 0 },
              languages: repos.map { |r| r[:language] }.compact.tally,
              most_recent: repos.first&.dig(:updated_at)
            }
          }
        else
          # Original HTTP-based implementation for non-test environments
          # Determine the correct URL based on whether it's a user or organization
          base_url = if org_name.present?
                       "https://api.github.com/orgs/#{org_name}/repos"
                     else
                       "https://api.github.com/users/#{username}/repos"
                     end

          url = "#{base_url}?sort=updated&per_page=#{limit}"
          
          response = super(
            url: url,
            headers: headers,
            cache_key: "github_repos_#{org_name || username}_#{limit}",
            cache_ttl: 30.minutes,
            rate_limit_key: 'github_api'
          )

          if response[:success] && response[:data].is_a?(Array)
            repos = response[:data].map do |repo|
              {
                name: repo['name'],
                full_name: repo['full_name'],
                description: repo['description'],
                language: repo['language'],
                stars: repo['stargazers_count'],
                forks: repo['forks_count'],
                open_issues: repo['open_issues_count'],
                private: repo['private'],
                updated_at: repo['updated_at'],
                url: repo['html_url']
              }
            end

            {
              count: repos.size,
              repositories: repos,
              summary: {
                total_stars: repos.sum { |r| r[:stars] || 0 },
                languages: repos.map { |r| r[:language] }.compact.tally,
                most_recent: repos.first&.dig(:updated_at)
              }
            }
          else
            {
              count: 0,
              repositories: [],
              summary: { total_stars: 0, languages: {}, most_recent: nil }
            }
          end
        end
      end
    end
  end
end