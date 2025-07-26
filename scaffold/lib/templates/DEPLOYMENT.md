# Deployment Guide

This guide covers deploying your Rails SaaS Starter application to various platforms.

## Quick Start

1. **Configure environment**: Copy `.env.example` to `.env` and fill in your values
2. **Validate setup**: Run `rails deploy:validate_env`
3. **Choose platform**: Select from Fly.io, Render, or Kamal deployment
4. **Deploy**: Follow platform-specific instructions below

## Environment Configuration

### Required Variables

```bash
# Core Rails configuration
SECRET_KEY_BASE=your_secret_key_base
DATABASE_URL=postgresql://user:pass@host:5432/dbname
REDIS_URL=redis://host:6379/0

# Application settings
APP_HOST=your-domain.com
FROM_EMAIL=noreply@your-domain.com
```

### Optional but Recommended

```bash
# AI/LLM Providers
OPENAI_API_KEY=sk-your_openai_key
ANTHROPIC_API_KEY=sk-ant-your_anthropic_key

# OAuth Providers
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Stripe Billing
STRIPE_SECRET_KEY=sk_live_your_stripe_key
STRIPE_PUBLISHABLE_KEY=pk_live_your_stripe_key

# Email (SMTP)
SMTP_HOST=smtp.your-provider.com
SMTP_USERNAME=your_smtp_user
SMTP_PASSWORD=your_smtp_pass
```

## Platform Deployment

### Fly.io

1. **Install Fly CLI**: [Install flyctl](https://fly.io/docs/getting-started/installing-flyctl/)

2. **Customize fly.toml**: Copy from `lib/templates/fly.toml` and update:
   ```toml
   app = "your-app-name"
   primary_region = "ord"  # Choose your region
   ```

3. **Launch app**:
   ```bash
   fly launch
   ```

4. **Set secrets**:
   ```bash
   fly secrets set SECRET_KEY_BASE=$(rails secret)
   fly secrets set OPENAI_API_KEY=your_key
   fly secrets set STRIPE_SECRET_KEY=your_key
   # ... add other secrets
   ```

5. **Deploy**:
   ```bash
   fly deploy
   ```

#### Fly.io with PostgreSQL and Redis

```bash
# Create PostgreSQL database
fly postgres create --name myapp-db

# Create Redis instance  
fly redis create --name myapp-redis

# Attach to your app
fly postgres attach myapp-db
fly redis attach myapp-redis
```

### Render

1. **Customize render.yaml**: Copy from `lib/templates/render.yaml` and update:
   ```yaml
   services:
     - type: web
       name: your-app-name
       # ... customize settings
   ```

2. **Connect repository**: 
   - Push your code to GitHub
   - Connect repository in Render dashboard
   - Use Blueprint deployment with your `render.yaml`

3. **Set environment variables** in Render dashboard:
   - Add all required secrets from your `.env` file
   - Database and Redis URLs are auto-configured

4. **Deploy**: Render will auto-deploy on git push

#### Render Manual Deployment

```bash
# Install Render CLI (optional)
npm install -g @render/cli

# Deploy via CLI
render blueprint launch
```

### Kamal

1. **Setup servers**: Ensure you have VPS/servers with Docker installed

2. **Customize kamal.yml**: Copy from `lib/templates/kamal.yml` and update:
   ```yaml
   service: your-app-name
   image: your-registry/your-app-name
   
   servers:
     web:
       hosts:
         - your-server-ip
   ```

3. **Setup container registry**: Configure Docker registry access:
   ```bash
   # For GitHub Container Registry
   echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin
   ```

4. **Configure secrets**: Create `.kamal/secrets` file:
   ```bash
   KAMAL_REGISTRY_PASSWORD=your_registry_token
   SECRET_KEY_BASE=your_secret
   DATABASE_URL=your_database_url
   # ... add other secrets
   ```

5. **Deploy**:
   ```bash
   # First time setup
   kamal setup
   
   # Regular deployments
   kamal deploy
   ```

#### Kamal with Accessories

For managed PostgreSQL and Redis, update `kamal.yml`:

```yaml
accessories:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: your_password
    directories:
      - data:/var/lib/postgresql/data
      
  redis:
    image: redis:7
    directories:
      - data:/data
```

## Database Setup

### PostgreSQL with pgvector

All platforms need the pgvector extension for AI features:

```sql
-- Run this on your PostgreSQL database
CREATE EXTENSION IF NOT EXISTS vector;
```

#### Platform-specific pgvector setup:

- **Fly.io**: Included in Fly PostgreSQL
- **Render**: Contact support to enable pgvector
- **Kamal**: Use `pgvector/pgvector` image or install manually

## Environment Bootstrapping

Use the provided Rake tasks for environment setup:

```bash
# Full environment bootstrap
rails deploy:bootstrap

# Individual validations
rails deploy:validate_env
rails deploy:validate_services
rails deploy:check_db
rails deploy:check_redis
```

## Secret Management

### Fly.io Secrets

```bash
fly secrets list
fly secrets set KEY=value
fly secrets unset KEY
```

### Render Environment Variables

Set in dashboard under: Service → Environment → Add Environment Variable

### Kamal Secrets

Store in `.kamal/secrets` (git-ignored):

```bash
echo "SECRET_KEY_BASE=$(rails secret)" >> .kamal/secrets
echo "DATABASE_URL=your_url" >> .kamal/secrets
```

## Health Checks

All deployments include a health check endpoint at `/health`:

```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "checks": {
    "database": {"healthy": true, "message": "Database connection successful"},
    "redis": {"healthy": true, "message": "Redis connection successful"}
  }
}
```

## Monitoring and Logs

### Fly.io

```bash
fly logs           # View logs
fly status        # Check app status
fly dashboard     # Open web dashboard
```

### Render

View logs and metrics in the Render dashboard under your service.

### Kamal

```bash
kamal app logs    # View application logs
kamal app exec "rails console"  # Execute commands
```

## Troubleshooting

### Common Issues

1. **Database connection errors**:
   - Verify `DATABASE_URL` is correctly set
   - Check pgvector extension is installed
   - Run `rails deploy:check_db`

2. **Redis connection errors**:
   - Verify `REDIS_URL` is correctly set
   - Check Redis service is running
   - Run `rails deploy:check_redis`

3. **Asset compilation failures**:
   - Ensure Node.js is available in build environment
   - Check for missing node_modules
   - Verify asset pipeline configuration

4. **Secret/environment variable issues**:
   - Run `rails deploy:validate_env`
   - Check platform-specific secret management
   - Verify all required variables are set

### Platform-specific Troubleshooting

#### Fly.io
```bash
fly ssh console    # SSH into running instance
fly logs --app your-app  # View detailed logs
```

#### Render
- Check build logs in dashboard
- Verify environment variables are set correctly
- Ensure proper service dependencies

#### Kamal
```bash
kamal app details  # Check deployment status
kamal accessory logs postgres  # Check database logs
```

## Continuous Deployment

### GitHub Actions

The template includes a CI/CD workflow that:
- Tests deployment configurations
- Validates environment setup
- Ensures application boots successfully

Customize `.github/workflows/deployment-test.yml` for your needs.

### Auto-deployment

- **Fly.io**: Use GitHub Actions with Fly deploy action
- **Render**: Auto-deploys on git push (configure in dashboard)
- **Kamal**: Setup GitHub Actions with Kamal deploy

## Advanced Configuration

### Custom Domains

- **Fly.io**: `fly certs create your-domain.com`
- **Render**: Add custom domain in dashboard
- **Kamal**: Configure in Traefik reverse proxy

### SSL/TLS

All platforms provide automatic SSL certificates:
- Fly.io: Automatic Let's Encrypt certificates
- Render: Automatic SSL for custom domains
- Kamal: Configured via Traefik in `kamal.yml`

### Scaling

- **Fly.io**: `fly scale count 3` or `fly scale memory 1024`
- **Render**: Scale in dashboard or via plan upgrade
- **Kamal**: Add more servers to `kamal.yml` hosts list