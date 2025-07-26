# Deploy Module

Provides deployment configuration and environment management tools for multiple platforms.

## Features

- **Multi-platform deployment configs** for Fly.io, Render, and Kamal
- **Environment configuration** with comprehensive `.env.example`
- **Deployment automation** with Rake tasks for bootstrapping environments
- **Health checks** for monitoring application status
- **CI/CD integration** with GitHub Actions for testing deployments
- **Docker support** with optimized production Dockerfile

## Deployment Platforms

### Fly.io
Deploy with automatic PostgreSQL and Redis provisioning:
```sh
fly launch
fly deploy
```

### Render
Deploy using Blueprint specification:
```sh
# Connect your GitHub repo to Render and it will auto-deploy
# Or use the Render CLI:
render blueprint launch
```

### Kamal
Deploy to your own servers with Docker:
```sh
kamal setup
kamal deploy
```

## Environment Management

### Bootstrap a new environment:
```sh
rails deploy:bootstrap
```

### Validate configuration:
```sh
rails deploy:validate_env
rails deploy:validate_services
```

### Check services:
```sh
rails deploy:check_db
rails deploy:check_redis
```

## Installation

Install this module via:

```sh
bin/synth add deploy
```

This will add:
- Deployment configuration files for all platforms
- Environment variable template
- Deployment automation scripts
- Health check endpoints
- CI/CD workflow for testing

## Configuration

1. Copy `.env.example` to `.env` and fill in your values
2. Customize deployment configs for your application
3. Set up secrets in your deployment platform
4. Run `rails deploy:validate_env` to verify setup

## Secret Management

### Fly.io
```sh
fly secrets set SECRET_KEY_BASE=your_secret
fly secrets set DATABASE_URL=your_db_url
```

### Render
Set environment variables in the Render dashboard under your service settings.

### Kamal
Store secrets in `.kamal/secrets` file (not committed to git):
```sh
echo "SECRET_KEY_BASE=your_secret" > .kamal/secrets
```