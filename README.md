# Rails SaaS Starter Template

A production-ready Rails template for building AI-native SaaS applications. Get up and running with a single command, then extend with modular features via an intuitive CLI.

## ⚡ Quick Start

### Option 1: Interactive Setup (Recommended)
```bash
bin/synth bootstrap
```
Choose from:
- 🎯 **Demo Setup** - Get running fast with sample data
- 🏗️ **New Application** - Full guided production setup  
- 🔧 **Custom Modules** - Pick specific features

### Option 2: Manual Setup
```bash
# 1. Install prerequisites
# Ruby 3.2+, Node.js 18+, PostgreSQL 14+, Redis 6+

# 2. Clone and setup
git clone <repository-url>
cd <app-name>
bundle install

# 3. Quick demo setup
bin/synth bootstrap

# 4. Start your application
rails db:create db:migrate db:seed
rails server
```

Visit `http://localhost:3000` and login with demo credentials.

## 🎯 What You Get

### Production-Ready Stack
- **Rails 7** with Hotwire (Turbo & Stimulus) and TailwindCSS
- **PostgreSQL** with pgvector extension for AI embeddings
- **Redis & Sidekiq** for background job processing
- **Authentication** via Devise with OAuth support
- **Multi-tenancy** with workspaces, teams, and role management

### AI-Native Features
- **Smart Prompt System** with versioning and variable interpolation
- **Async LLM Jobs** with Sidekiq integration and retry logic
- **Multi-Context Provider (MCP)** for dynamic prompt enrichment
- **Multiple AI Providers** (OpenAI, Anthropic, Cohere, Hugging Face)

### SaaS Essentials
- **Stripe Billing** with subscriptions, metered usage, and invoicing
- **Admin Panel** with impersonation, audit logs, and feature flags
- **JSON:API** with auto-generated OpenAPI documentation
- **Deployment** configs for Fly.io, Render, and Kamal
- **Comprehensive Testing** with mocks for external services

## 🔧 CLI Commands

The `bin/synth` CLI makes managing your application simple and consistent:

```bash
# Get started
bin/synth bootstrap              # Interactive setup wizard
bin/synth doctor                 # Check system health

# Manage modules  
bin/synth list                   # Show available modules
bin/synth add billing            # Install Stripe billing
bin/synth remove cms             # Remove blog engine
bin/synth info ai                # Show module details

# Development
bin/synth test billing           # Run module tests
```

## 📦 Available Modules

| Module | Description | Status |
|--------|-------------|--------|
| `auth` | User authentication with Devise & OAuth | Core |
| `billing` | Stripe subscriptions and metered billing | Optional |
| `ai` | LLM integration with multiple providers | Optional |
| `admin` | Admin panel with impersonation & audit logs | Optional |
| `api` | JSON:API with auto-generated OpenAPI docs | Optional |
| `cms` | Blog engine with SEO and sitemap | Optional |
| `deploy` | Deployment configs for major platforms | Optional |

## 📚 Documentation

### Quick Links
- [Module Documentation](docs/modules/) - Detailed guides for each module
- [Implementation Guides](docs/implementation/) - Technical implementation details
- [Admin Features](docs/admin/) - Admin panel and management features

### Module-Specific Docs
- [AI & LLM Integration](docs/modules/ai.md)
- [Billing & Stripe Setup](docs/modules/billing.md)
- [Authentication System](docs/modules/auth.md)
- [Admin Panel Features](docs/admin/admin-panel.md)

## 🚀 Deployment

Deploy to your preferred platform:

```bash
# Fly.io (recommended)
bin/synth add deploy
fly deploy

# Render
render deploy

# Kamal (self-hosted)
kamal deploy
```

See [deployment documentation](docs/modules/deploy.md) for platform-specific setup.

## 🧪 Testing

Run the comprehensive test suite:

```bash
# All tests
bin/synth test

# Specific module
bin/synth test billing

# Check system health
bin/synth doctor
```

## 🤝 Contributing

This project follows the guidelines in [AGENTS.md](docs/guides/AGENTS.md):

1. **Pick a task** from the project board
2. **Plan your work** by breaking it into small steps
3. **Implement iteratively** with frequent commits
4. **Write tests** and ensure they pass
5. **Update documentation** as needed

## 📄 License

This project is available under the [MIT License](LICENSE).

---

**Ready to build your SaaS?** Run `bin/synth bootstrap` to get started! 🚀