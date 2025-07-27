# Deployment Checklist for Rails SaaS Starter

Use this checklist to ensure a smooth deployment across all supported platforms.

## Pre-Deployment Checklist

### Environment Configuration ✅
- [ ] Copy `.env.production.example` to `.env.production` 
- [ ] Generate `SECRET_KEY_BASE` with `rails secret`
- [ ] Set `RAILS_MASTER_KEY` (from `config/master.key`)
- [ ] Configure database URL with PostgreSQL 16+
- [ ] Configure Redis URL for caching and Sidekiq
- [ ] Set application domain (`APP_HOST`)
- [ ] Configure email delivery (SMTP/SendGrid/Mailgun)

### Required Secrets ✅
- [ ] `SECRET_KEY_BASE` - Rails application secret
- [ ] `RAILS_MASTER_KEY` - For encrypted credentials
- [ ] `DATABASE_URL` - PostgreSQL connection string
- [ ] `REDIS_URL` - Redis connection string

### Optional but Recommended ✅
- [ ] AI Provider API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`)
- [ ] OAuth credentials (Google, GitHub, Slack)
- [ ] Stripe keys for billing (if using billing module)
- [ ] Error tracking (Sentry DSN)
- [ ] Email delivery credentials

### Database Setup ✅
- [ ] PostgreSQL 16+ with `pgvector` extension
- [ ] Run `CREATE EXTENSION IF NOT EXISTS vector;` on your database
- [ ] Verify database supports SSL connections
- [ ] Set up database backups

### Performance & Security ✅
- [ ] Enable SSL/TLS (all platforms support automatic certificates)
- [ ] Configure rate limiting (`RACK_ATTACK_ENABLED=true`)
- [ ] Set appropriate resource limits (CPU/memory)
- [ ] Configure monitoring and health checks

## Platform-Specific Deployment

### Fly.io Deployment 🪰

1. **Setup**
   ```bash
   # Install Fly CLI
   brew install flyctl  # or curl -L https://fly.io/install.sh | sh
   
   # Login to Fly
   fly auth login
   ```

2. **Configuration**
   ```bash
   # Copy and customize fly.toml
   cp scaffold/lib/templates/fly.toml ./fly.toml
   # Edit app name and region in fly.toml
   ```

3. **Launch Application**
   ```bash
   # Launch app (creates app and initial deployment)
   fly launch
   
   # Or create app without deploying
   fly apps create your-app-name
   ```

4. **Add PostgreSQL and Redis**
   ```bash
   # Create and attach PostgreSQL (with pgvector)
   fly postgres create --name your-app-postgres
   fly postgres attach your-app-postgres
   
   # Create and attach Redis
   fly redis create --name your-app-redis
   fly redis attach your-app-redis
   ```

5. **Set Secrets**
   ```bash
   # Required secrets
   fly secrets set SECRET_KEY_BASE=$(rails secret)
   fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
   
   # Optional secrets
   fly secrets set OPENAI_API_KEY=your_key
   fly secrets set STRIPE_SECRET_KEY=your_key
   # ... add other secrets as needed
   ```

6. **Deploy**
   ```bash
   fly deploy
   ```

7. **Post-Deployment**
   ```bash
   # Check status
   fly status
   
   # View logs
   fly logs
   
   # Open app
   fly open
   ```

### Render Deployment 🎨

1. **Setup Repository**
   - Push code to GitHub
   - Connect repository in Render dashboard

2. **Blueprint Deployment**
   ```bash
   # Copy render.yaml to project root
   cp scaffold/lib/templates/render.yaml ./render.yaml
   # Edit service names and regions as needed
   ```

3. **Deploy via Dashboard**
   - Create new "Blueprint" in Render dashboard
   - Point to your GitHub repository
   - Render will read `render.yaml` and create all services

4. **Environment Variables**
   Set in Render dashboard for each service:
   ```
   SECRET_KEY_BASE=your_secret_key_base
   RAILS_MASTER_KEY=your_master_key
   OPENAI_API_KEY=your_openai_key
   STRIPE_SECRET_KEY=your_stripe_key
   # ... other secrets from .env.production.example
   ```

5. **Post-Deployment**
   - Database and Redis URLs are auto-configured
   - SSL certificates are automatic
   - Monitor deployments in Render dashboard

### Kamal Deployment 🐋

1. **Server Setup**
   ```bash
   # Ensure servers have Docker installed
   # Setup SSH key access to servers
   ```

2. **Container Registry**
   ```bash
   # For GitHub Container Registry
   echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin
   ```

3. **Configuration**
   ```bash
   # Copy and customize kamal.yml
   cp scaffold/lib/templates/kamal.yml ./config/deploy.yml
   # Edit server IPs, domains, and registry details
   ```

4. **Secrets Management**
   ```bash
   # Create .kamal/secrets file (git-ignored)
   mkdir -p .kamal
   cp scaffold/lib/templates/.env.production.example .kamal/secrets
   # Fill in actual values in .kamal/secrets
   ```

5. **First Deployment**
   ```bash
   # Install Kamal
   gem install kamal
   
   # Setup servers and deploy
   kamal setup
   ```

6. **Regular Deployments**
   ```bash
   kamal deploy
   ```

7. **Post-Deployment**
   ```bash
   # Check status
   kamal app details
   
   # View logs
   kamal app logs
   
   # Execute commands
   kamal app exec "rails console"
   ```

## Post-Deployment Verification

### Health Checks ✅
- [ ] Visit `/health` endpoint returns HTTP 200
- [ ] Database connectivity test passes
- [ ] Redis connectivity test passes
- [ ] SSL certificate is valid and active

### Application Testing ✅
- [ ] Homepage loads correctly
- [ ] User registration/login works
- [ ] Background jobs are processing (Sidekiq)
- [ ] Email delivery is working
- [ ] AI features work (if enabled)
- [ ] Billing features work (if enabled)

### Performance & Monitoring ✅
- [ ] Set up error tracking (Sentry)
- [ ] Configure performance monitoring
- [ ] Set up log aggregation
- [ ] Configure alerts for downtime/errors
- [ ] Test scaling (add/remove instances)

### Security ✅
- [ ] HTTPS is enforced
- [ ] Security headers are configured
- [ ] Rate limiting is active
- [ ] Database connections use SSL
- [ ] Secrets are properly secured

## Troubleshooting Common Issues

### Database Connection Issues
```bash
# Test database connectivity
rails db:migrate:status

# Enable pgvector extension
rails runner "ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS vector;')"
```

### Redis Connection Issues
```bash
# Test Redis connectivity
rails runner "Redis.current.ping"
```

### Asset Issues
```bash
# Recompile assets
rails assets:precompile

# Clear cache
rails tmp:cache:clear
```

### SSL/TLS Issues
- Verify domain DNS points to deployment
- Check certificate auto-renewal settings
- Ensure FORCE_SSL=true is set

## Scaling Considerations

### Fly.io Scaling
```bash
# Scale machines
fly scale count 3

# Scale memory
fly scale memory 2048

# Scale by region
fly scale count 2 --region ord
fly scale count 1 --region iad
```

### Render Scaling
- Upgrade plan in dashboard (Starter → Standard → Pro)
- Horizontal scaling available on Standard+ plans

### Kamal Scaling
- Add more servers to `config/deploy.yml` hosts list
- Configure load balancer (Traefik handles this automatically)

## Backup & Recovery

### Database Backups
- **Fly.io**: `fly postgres backup list` / `fly postgres backup restore`
- **Render**: Automatic daily backups on Standard+ plans
- **Kamal**: Configure backup strategy for self-hosted PostgreSQL

### Application Backups
- Store uploaded files in cloud storage (S3, CloudFlare R2)
- Keep encrypted copies of secrets and configuration
- Document recovery procedures

## Maintenance

### Regular Updates
- [ ] Keep dependencies updated (`bundle update`, `npm update`)
- [ ] Update base Docker images
- [ ] Monitor security advisories
- [ ] Update platform configurations as needed

### Monitoring Deployments
- Set up deployment notifications
- Monitor error rates after deployments
- Keep rollback procedures documented
- Test disaster recovery procedures regularly