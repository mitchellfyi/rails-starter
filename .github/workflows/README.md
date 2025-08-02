# RailsPlan CI GitHub Action

This directory contains the GitHub Action workflow for validating RailsPlan applications in CI/CD environments.

## Quick Setup

Add this to your `.github/workflows/ci.yml`:

```yaml
name: CI
on: [push, pull_request]

jobs:
  railsplan-validation:
    uses: ./.github/workflows/railsplan-ci.yml
```

## Files

- `railsplan-ci.yml` - Main CI validation workflow
- `test-railsplan-ci.yml` - Test workflow for validating the action itself

## What It Does

1. **Sets up environment** - Ruby, Rails, PostgreSQL, Redis
2. **Runs `railsplan doctor --ci`** - System diagnostics and health checks
3. **Runs `railsplan verify --ci`** - Application integrity verification  
4. **Validates database schema** - Ensures schema can be loaded
5. **Checks test coverage** - Verifies generated code has tests
6. **Uploads artifacts** - Reports and logs for debugging
7. **Comments on PRs** - Summary of validation results

## Requirements

Your Rails application should have:

- `bin/railsplan` executable (from RailsPlan template)
- `.railsplan/context.json` (run `railsplan index` to generate)
- Standard Rails structure with `db/schema.rb`

## CI Failure Conditions

The action fails if:

- Schema cannot be loaded (`rails db:schema:load` fails)
- `railsplan doctor` finds critical issues
- `railsplan verify` finds integrity problems
- Generated code lacks test coverage
- Uncommitted changes exist in `.railsplan/` directory

See [complete documentation](../docs/github-action.md) for detailed usage and configuration options.