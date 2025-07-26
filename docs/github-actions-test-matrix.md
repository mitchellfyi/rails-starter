# GitHub Actions Test Matrix Documentation

This document explains the comprehensive test matrix implemented in `.github/workflows/test.yml` for the Rails SaaS Starter Template.

## Overview

The workflow automatically tests the template across multiple environment combinations to ensure compatibility and reliability. It runs on:
- All pull requests to the `main` branch
- Direct pushes to the `main` branch

## Test Matrix

The workflow tests the following combinations:

### Ruby Versions
- **Ruby 3.2**: Current stable version
- **Ruby 3.3**: Latest stable version

### Rails Versions
- **Rails Edge**: Development version of Rails (using `--dev` flag)

### PostgreSQL Versions
- **PostgreSQL 14**: Minimum supported version
- **PostgreSQL 15**: Recommended version
- **PostgreSQL 16**: Latest version

This creates a total of **6 test combinations** (2 Ruby × 1 Rails × 3 PostgreSQL).

## Test Process

For each matrix combination, the workflow:

1. **Environment Setup**
   - Sets up Ruby, Node.js, PostgreSQL, and Redis services
   - Installs PostgreSQL extensions (including `pgvector`)
   - Configures test database and Redis connections

2. **Template Generation**
   - Creates a new Rails application using the template
   - Generates deployment configurations (Fly.io, Render, Kamal)
   - Creates test files and coverage setup

3. **Dependency Installation**
   - Caches Ruby gems and Node.js modules for performance
   - Runs `bundle install` and `yarn install`
   - Sets up database and runs migrations

4. **Test Execution**
   - Runs the complete test suite (RSpec or Rails test)
   - Tests AI module functionality via `bin/synth test ai`
   - Validates deployment configurations in dry-run mode
   - Checks for deprecation warnings

5. **Quality Assurance**
   - Generates test coverage reports with SimpleCov
   - Uploads test artifacts on failure for debugging
   - Validates all deployment configuration syntax

## Deployment Configuration Testing

The workflow validates three deployment platforms:

### Fly.io (`fly.toml`)
- Validates TOML syntax using `toml-rb` gem
- Checks application configuration structure
- Ensures resource allocation settings are valid

### Render (`render.yaml`)
- Validates YAML syntax and structure
- Checks service definitions and environment variables
- Validates database and Redis configurations

### Kamal (`config/deploy.yml`)
- Validates YAML syntax for Kamal deployment
- Checks server definitions and registry settings
- Validates environment variable and accessor configurations

## AI Module Testing

The workflow includes specialized testing for the AI module:

1. **CLI Tool Testing**
   - Tests `bin/synth list` command
   - Runs `bin/synth doctor` diagnostics
   - Executes `bin/synth test ai` if AI module is installed

2. **Stub Validation**
   - Verifies prompt template stubs
   - Tests LLM job processing stubs
   - Validates MCP (Multi-Context Provider) integration

## Caching Strategy

To optimize build times, the workflow caches:

- **Ruby Gems**: Cached by Ruby version, Rails version, and `Gemfile.lock` hash
- **Node Modules**: Cached by `yarn.lock` hash
- **PostgreSQL Extensions**: Installed once per job

## Error Handling

The workflow includes comprehensive error handling:

- **Fail-fast disabled**: All matrix combinations run even if some fail
- **Artifact upload**: Logs and test results uploaded on failure
- **Deprecation detection**: Build fails if deprecation warnings found
- **Coverage requirements**: Configurable minimum coverage thresholds

## Customization

### Adding Ruby Versions
To test additional Ruby versions, update the matrix in `.github/workflows/test.yml`:

```yaml
matrix:
  ruby-version: ['3.2', '3.3', '3.4']  # Add new versions here
```

### Adding Rails Versions
To test specific Rails versions instead of Edge:

```yaml
matrix:
  rails-version: ['7.1', '7.2', 'edge']  # Add specific versions
```

### Adding PostgreSQL Versions
To test additional PostgreSQL versions:

```yaml
matrix:
  postgres-version: ['13', '14', '15', '16']  # Add versions as needed
```

## Performance Optimization

The workflow is optimized for speed and resource usage:

- **Parallel execution**: All matrix combinations run in parallel
- **Efficient caching**: Multi-level cache strategy reduces build times
- **Minimal artifact storage**: Only failure artifacts are retained
- **Service health checks**: Ensures services are ready before testing

## Integration with Development Workflow

The test matrix integrates seamlessly with the development process:

- **PR Validation**: Every pull request is tested across all environments
- **Branch Protection**: Can be configured as required status check
- **Coverage Reporting**: Results can integrate with coverage services
- **Deployment Validation**: Ensures deployment configs are always valid

This comprehensive test matrix ensures the Rails SaaS Starter Template works reliably across all supported environments and deployment platforms.