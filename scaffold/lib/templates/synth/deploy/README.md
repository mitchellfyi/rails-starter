# Deploy Module

This module provides deployment configurations and scripts for multiple platforms including Fly.io, Render, and Kamal (Docker-based deployment).

## Features

- **Multi-Platform Support**: Fly.io, Render, and Kamal configurations
- **Docker Integration**: Production-ready Dockerfile and build scripts
- **CI/CD Workflows**: GitHub Actions for automated deployments
- **Environment Management**: Secure secrets and environment variable handling
- **Database Setup**: PostgreSQL and Redis configuration for production

## Installation

```bash
bin/synth add deploy
```

This installs:
- Kamal for Docker-based deployments
- Dockerfile and production build scripts
- Platform-specific configuration files
- GitHub Actions deployment workflows
- Deployment helper scripts

## Deployment Options

### 1. Fly.io (Recommended for Rails)

**Setup:**
```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Initialize app
fly launch --no-deploy

# Update fly.toml with your app name
# Deploy
bin/deploy-fly
```

**Configuration:**
- Edit `fly.toml` with your app name and region
- Set secrets: `fly secrets set RAILS_MASTER_KEY=your_key`
- Configure database: `fly postgres create`

### 2. Render

**Setup:**
- Connect your GitHub repository to Render
- Use the provided `render.yaml` configuration
- Set environment variables in Render dashboard

**Configuration:**
```bash
# Deploy automatically on git push to main
git push origin main

# Or use manual deploy script
bin/deploy-render
```

### 3. Kamal (Self-hosted)

**Setup:**
```bash
# Install Kamal
gem install kamal

# Configure your servers in config/deploy.yml
# Setup infrastructure
bin/deploy-kamal setup

# Deploy application
bin/deploy-kamal
```

## Configuration Files

### Fly.io (`fly.toml`)
```toml
app = "your-app-name"
primary_region = "iad"

[http_service]
  internal_port = 3000
  force_https = true

[env]
  RAILS_ENV = "production"
```

### Render (`render.yaml`)
```yaml
services:
  - type: web
    name: your-app-name
    env: ruby
    buildCommand: "./bin/render-build.sh"
    startCommand: "bundle exec puma -C config/puma.rb"
```

### Kamal (`config/deploy.yml`)
```yaml
service: your-app-name
image: your-registry/your-app-name

servers:
  web:
    hosts:
      - your-server-ip

accessories:
  db:
    image: postgres:15
  redis:
    image: redis:7
```

## Environment Variables

### Required Secrets
```bash
# All platforms need these
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgresql://...
REDIS_URL=redis://...

# Stripe (if using billing module)
STRIPE_PUBLISHABLE_KEY=pk_...
STRIPE_SECRET_KEY=sk_...

# OpenAI (if using AI module)
OPENAI_API_KEY=sk-...
```

### Platform-Specific Setup

**Fly.io:**
```bash
fly secrets set RAILS_MASTER_KEY=your_key
fly secrets set DATABASE_URL=postgresql://...
```

**Render:**
Set in Render dashboard under Environment Variables

**Kamal:**
Set in `.env` file (not committed to git):
```bash
KAMAL_REGISTRY_PASSWORD=your_password
RAILS_MASTER_KEY=your_key
```

## Database Setup

### Fly.io
```bash
# Create PostgreSQL database
fly postgres create --name your-app-db

# Connect to your app
fly postgres attach your-app-db
```

### Render
PostgreSQL is configured automatically via `render.yaml`

### Kamal
Database runs as Docker container on your server

## CI/CD Integration

### GitHub Actions
The module includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) that:
- Runs tests on every push
- Deploys to production on pushes to main branch
- Supports multiple deployment platforms

### Required Secrets
Add these to your GitHub repository secrets:
```
FLY_API_TOKEN          # For Fly.io deployments
KAMAL_REGISTRY_PASSWORD # For Kamal deployments
RAILS_MASTER_KEY       # For all deployments
```

## Deployment Scripts

### Quick Deploy Commands
```bash
# Deploy to Fly.io
bin/deploy-fly

# Deploy to Render (via git push)
bin/deploy-render

# Deploy with Kamal
bin/deploy-kamal

# First-time Kamal setup
bin/deploy-kamal setup
```

### Manual Deployment Steps

1. **Build and test locally:**
   ```bash
   bundle install
   bundle exec rails test
   bundle exec rails assets:precompile
   ```

2. **Deploy to chosen platform:**
   ```bash
   # Choose one:
   bin/deploy-fly
   bin/deploy-render
   bin/deploy-kamal
   ```

3. **Run post-deployment tasks:**
   ```bash
   # Migrate database (platform-specific)
   fly ssh console -C "rails db:migrate"
   ```

## Production Optimizations

### Dockerfile
- Multi-stage build for smaller images
- Non-root user for security
- Asset precompilation
- Bootsnap for faster boot times

### Performance
- Puma web server configuration
- Redis for caching and background jobs
- PostgreSQL with proper indexing
- CDN for asset delivery

### Security
- Secrets management
- Environment isolation
- SSL/TLS termination
- Database encryption

## Monitoring and Logging

### Fly.io
```bash
# View logs
fly logs

# Monitor metrics
fly dashboard
```

### Render
- Built-in monitoring dashboard
- Log streaming in web interface

### Kamal
```bash
# View logs
kamal app logs

# Check status
kamal app details
```

## Troubleshooting

### Common Issues
1. **Build failures**: Check Ruby version in Dockerfile
2. **Database connection**: Verify DATABASE_URL format
3. **Asset compilation**: Ensure RAILS_MASTER_KEY is set
4. **Memory issues**: Adjust server resources

### Debug Commands
```bash
# Fly.io console access
fly ssh console

# Kamal console access
kamal app exec -i --reuse "rails console"

# Check environment
kamal app exec "printenv"
```

## Testing

```bash
bin/synth test deploy
```

## Version

Current version: 1.0.0