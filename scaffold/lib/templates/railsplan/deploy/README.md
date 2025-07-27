# Deploy Module

This module provides deployment configurations and CI/CD setups for three popular platforms:

- **Fly.io** - Simple container deployment with global edge locations
- **Render** - Managed platform with automatic scaling and zero-config databases
- **Kamal** - Self-hosted deployment to your own servers

## Installation

```bash
bin/railsplan add deploy
```

This will create:
- `fly.toml` - Fly.io configuration
- `render.yaml` - Render deployment specification  
- `config/deploy.yml` - Kamal deployment configuration
- `Dockerfile` - Multi-stage container build
- `.dockerignore` - Container build exclusions
- `.env.production.example` - Production environment template
- `.github/workflows/` - Deployment workflows

## Platform Setup

### Fly.io

Fly.io provides simple container deployment with excellent global performance.

**Setup:**
1. Install the Fly CLI: `curl -L https://fly.io/install.sh | sh`
2. Create a Fly account: `flyctl auth signup`
3. Launch your app: `flyctl launch`
4. Set secrets: `flyctl secrets set SECRET_KEY_BASE=xxx`

**Configuration:**
- Edit `fly.toml` to customize your deployment
- Set `app` name to match your Fly app
- Configure regions, scaling, and resources
- Add secrets via `flyctl secrets set KEY=value`

**Deploy:**
```bash
flyctl deploy
```

**Services configured:**
- Web server on port 3000
- Sidekiq worker process
- PostgreSQL database with pgvector
- Redis for caching and jobs

### Render

Render provides a managed platform with zero-config databases and automatic scaling.

**Setup:**
1. Connect your GitHub repository to Render
2. Create a new Blueprint
3. Use `render.yaml` for configuration
4. Set environment variables in dashboard

**Configuration:**
- Edit `render.yaml` to customize services
- Set app name throughout the file
- Configure regions and instance types
- Add secrets via Render dashboard

**Deploy:**
Automatic deployment on git push to main branch.

**Services configured:**
- Web service with health checks
- Background worker for Sidekiq
- PostgreSQL database with pgvector
- Redis for caching and jobs

### Kamal

Kamal deploys your app to your own servers using Docker containers.

**Setup:**
1. Install Kamal: `gem install kamal`
2. Set up your servers with Docker
3. Configure SSH access to servers
4. Edit `config/deploy.yml` with your details

**Configuration:**
- Add your server IPs to `config/deploy.yml`
- Configure registry credentials
- Set up domain and SSL certificates
- Add secrets via `kamal env push`

**Deploy:**
```bash
kamal setup    # First time only
kamal deploy   # Subsequent deployments
```

**Services configured:**
- Web application with Traefik load balancer
- Sidekiq workers on dedicated servers
- PostgreSQL and Redis as accessories

## Environment Variables

Copy `.env.production.example` to `.env.production` and configure:

### Required Variables

```bash
# Database
DATABASE_URL=postgres://user:password@host:5432/database

# Redis  
REDIS_URL=redis://host:6379/0

# Rails
SECRET_KEY_BASE=your_secret_key_base
RAILS_MASTER_KEY=your_master_key
```

### Optional Variables

```bash
# Email (choose one provider)
SMTP_SERVER=smtp.gmail.com
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# OAuth providers
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Stripe billing
STRIPE_SECRET_KEY=sk_live_your_stripe_key
STRIPE_PUBLIC_KEY=pk_live_your_stripe_key

# AI providers  
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
```

## Continuous Integration

The module includes GitHub Actions workflows for:

### Main CI Pipeline (`.github/workflows/ci.yml`)
- Matrix testing across Ruby versions and OSs
- PostgreSQL and Redis services
- Template installation validation
- Configuration syntax validation
- Container image building and publishing

### Platform Deployments
- `fly-deploy.yml` - Deploys to Fly.io on push
- `kamal-deploy.yml` - Deploys with Kamal on push
- Render deploys automatically via Blueprint

## Container Image Publishing

When you create a release (git tag), the CI pipeline:
1. Builds a multi-arch Docker image
2. Publishes to GitHub Container Registry
3. Tags with semantic version numbers

Images are available at:
```
ghcr.io/your-username/your-app:latest
ghcr.io/your-username/your-app:v1.0.0
```

## Health Checks

All platforms are configured with health checks at `/health`. 

Add this route to your Rails app:
```ruby
# config/routes.rb
get '/health', to: 'health#show'
```

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: { status: 'ok', timestamp: Time.current }
  end
end
```

## SSL/TLS

All platforms are configured for HTTPS:
- **Fly.io**: Automatic SSL with Let's Encrypt
- **Render**: Automatic SSL included
- **Kamal**: Traefik with Let's Encrypt

## Monitoring

Consider adding these services:
- **Error tracking**: Sentry, Rollbar, Bugsnag
- **Performance**: New Relic, Scout, Skylight  
- **Uptime**: Pingdom, UptimeRobot
- **Logs**: Papertrail, Logtail

## Secrets Management

### Fly.io
```bash
flyctl secrets set SECRET_KEY_BASE=xxx
flyctl secrets list
```

### Render
Set via dashboard under Environment > Environment Variables

### Kamal  
```bash
kamal env push
kamal env list
```

## Troubleshooting

### Common Issues

**Build failures:**
- Check Dockerfile syntax
- Verify all dependencies are installed
- Review build logs for missing packages

**Deploy failures:**
- Validate configuration syntax
- Check secrets are set correctly
- Verify server connectivity (Kamal)

**Runtime errors:**
- Check environment variables
- Review application logs  
- Verify database connections

### Platform-Specific Commands

**Fly.io debugging:**
```bash
flyctl logs
flyctl ssh console
flyctl status
```

**Render debugging:**
- View logs in dashboard
- Check service health
- Review event history

**Kamal debugging:**
```bash
kamal app logs
kamal app exec -i bash
kamal config
```

## Customization

The deployment configurations are templates. Customize them for your needs:

- **Scaling**: Adjust instance counts and sizes
- **Regions**: Choose optimal locations for your users  
- **Resources**: Configure CPU, memory, and storage
- **Services**: Add databases, caches, or other services
- **Networking**: Configure load balancers and SSL

## Cost Optimization

- **Fly.io**: Use auto-start/stop for low-traffic apps
- **Render**: Choose appropriate instance sizes
- **Kamal**: Optimize server utilization

See each platform's documentation for detailed pricing and optimization guides.