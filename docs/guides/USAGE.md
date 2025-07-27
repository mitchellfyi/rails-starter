# Rails SaaS Starter Template - Usage Guide

## 🚀 Quick Start

### 1. Generate a New Application

```bash
# Create a new Rails SaaS application using the template
rails new myapp --dev -d postgresql -m https://raw.githubusercontent.com/mitchellfyi/rails-starter/main/scaffold/template.rb

# Navigate to your new application
cd myapp

# Complete the setup
bin/setup
```

### 2. Configure Environment

```bash
# Copy environment variables template
cp .env.example .env

# Edit .env with your actual values
# - Database credentials
# - OAuth provider keys (Google, GitHub, Slack)
# - Redis URL
# - Devise secret key
```

### 3. Start Development

```bash
# Start all services (Rails, TailwindCSS, Sidekiq)
bin/dev

# Or start individual services:
bin/rails server          # Rails app on port 3000
bin/rails tailwindcss:watch  # TailwindCSS compiler
bundle exec sidekiq       # Background job processor
```

## 🔧 Key Features Included

### Authentication & Authorization
- **Devise** with email/password authentication
- **OmniAuth** for Google, GitHub, Slack login
- User confirmations, account lockout, session timeouts
- Role-based authorization with **Pundit**

### Team/Workspace Management
- Multi-tenant workspace architecture
- Role-based memberships (owner, admin, member)
- Team invitation system with email tokens
- Slug-based URLs with **FriendlyId**

### API Layer
- **JSON:API** compliant REST endpoints
- Structured under `/api/v1/` namespace
- Automatic serialization with **JSONAPI::Serializer**
- Comprehensive error handling

### Background Jobs
- **Sidekiq** + **Redis** for async processing
- Web UI at `/admin/sidekiq` (admin users only)
- Configurable job queues and concurrency

### Frontend
- **TailwindCSS** for styling
- **Hotwire** (Turbo + Stimulus) for interactivity
- Modern Rails 8 frontend patterns

## 📋 API Usage Examples

### Authentication
```bash
# Register a new user
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"user@example.com","password":"password123","first_name":"John","last_name":"Doe"}}'

# OAuth login (redirect to provider)
open http://localhost:3000/users/auth/google_oauth2
```

### Workspaces
```bash
# Get user's workspaces
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/workspaces

# Create a new workspace
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"workspace":{"name":"My Team","description":"Our awesome workspace"}}' \
  http://localhost:3000/api/v1/workspaces

# Get workspace members
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:3000/api/v1/workspaces/my-team/memberships
```

### Team Invitations
```bash
# Invite a team member
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"invitation":{"email":"newmember@example.com","role":"member"}}' \
  http://localhost:3000/workspaces/my-team/invitations
```

## 🛠️ Development Tools

### CLI Commands
```bash
# List installed modules
bin/synth list

# Validate setup
bin/synth doctor

# Run tests
bin/synth test

# Future: Add new modules
bin/synth add billing    # (coming soon)
bin/synth add ai         # (coming soon)
```

### Database Management
```bash
# Create and migrate database
bin/rails db:create db:migrate

# Add pgvector extension
bin/rails db:migrate

# Create seed data
bin/rails db:seed
```

### Testing
```bash
# Run full test suite
bin/rails test

# Or with RSpec (if configured)
bundle exec rspec

# Run specific tests
bundle exec rspec spec/models/user_spec.rb
```

## 🏗️ Architecture

### Models
- **User**: Authentication, profiles, admin roles
- **Workspace**: Teams/organizations with slugs
- **Membership**: User-workspace relationships with roles
- **Invitation**: Token-based team invitations

### Controllers
- **Web Controllers**: Standard Rails controllers for HTML
- **API Controllers**: JSON:API compliant REST endpoints
- **OmniAuth**: OAuth callback handling

### Serializers
- **JSON:API** format for all API responses
- Relationship handling for associated models
- Consistent error response format

## 🚀 Deployment

The template is configured for easy deployment to:
- **Fly.io** (recommended)
- **Render** 
- **Heroku**
- **VPS** with Kamal

Required services:
- PostgreSQL with pgvector extension
- Redis for Sidekiq

## 🎯 Next Steps

1. **Customize branding** and styling
2. **Add business logic** specific to your SaaS
3. **Configure monitoring** and error tracking
4. **Set up CI/CD** pipelines
5. **Add more OAuth providers** as needed
6. **Implement billing** with Stripe (coming soon)

## 📚 Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Devise Documentation](https://github.com/heartcombo/devise)
- [JSON:API Specification](https://jsonapi.org/)
- [TailwindCSS Documentation](https://tailwindcss.com/)
- [Sidekiq Documentation](https://github.com/mperham/sidekiq)

---

**Happy building!** 🎉