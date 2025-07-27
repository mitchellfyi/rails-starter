# Rails SaaS Starter Template Documentation

Welcome to the comprehensive documentation for the Rails SaaS Starter Template. This documentation is organized to help you get started quickly and then dive deep into specific features.

## 🚀 Quick Start

1. **Get Started Fast**: Run `bin/synth bootstrap` for interactive setup
2. **Check System Health**: Run `bin/synth doctor` to validate your setup
3. **Explore Modules**: Run `bin/synth list` to see available features

## 📚 Documentation Structure

### Getting Started
- [Main README](../README.md) - Quick start and overview
- [Usage Guide](guides/USAGE.md) - Detailed usage instructions
- [Contributing Guide](guides/AGENTS.md) - How to contribute to the project

### Module Documentation
- [Authentication (auth)](modules/auth.md) - User authentication with Devise & OAuth
- [AI Integration (ai)](modules/ai.md) - LLM integration and prompt management
- [Admin Panel (admin)](admin/ADMIN_PANEL.md) - Admin features and management
- [API (api)](modules/api.md) - JSON:API with auto-generated docs
- [Billing (billing)](modules/billing.md) - Stripe integration and subscriptions
- [CMS/Blog (cms)](modules/cms.md) - Content management system
- [Deployment (deploy)](modules/deploy.md) - Platform deployment guides
- [All Modules](modules/README.md) - Complete module index

### Implementation Guides
- [AI Usage Estimator](implementation/AI_USAGE_ESTIMATOR_SUMMARY.md)
- [Agent Implementation](implementation/AGENT_IMPLEMENTATION_SUMMARY.md)
- [JSON API Implementation](implementation/JSON_API_IMPLEMENTATION.md)
- [MCP Workspace Implementation](implementation/MCP_WORKSPACE_IMPLEMENTATION.md)
- [Token Usage Tracking](implementation/TOKEN_USAGE_TRACKING.md)
- [All Implementation Guides](implementation/) - Technical deep dives

### Configuration & Setup
- [Accessibility Guidelines](guides/ACCESSIBILITY.md)
- [Bootstrap CLI](modules/BOOTSTRAP_CLI.md)
- [Seeds & Sample Data](modules/SEEDS.md)
- [System Prompts](modules/SYSTEM_PROMPTS.md)
- [I18n Configuration](modules/I18N_SEEDS.md)

## 🔧 CLI Commands Reference

```bash
# Setup and getting started
bin/synth bootstrap              # Interactive setup wizard  
bin/synth doctor                 # System health check

# Module management
bin/synth list                   # Show all modules
bin/synth list --available       # Show only available modules
bin/synth list --installed       # Show only installed modules
bin/synth add billing            # Install billing module
bin/synth remove cms --force     # Remove CMS module
bin/synth info ai                # Show module details

# Development and testing
bin/synth test                   # Run all tests
bin/synth test billing           # Run module-specific tests
```

## 🎯 Feature Overview

### Core Features (Always Available)
- **Ruby on Rails 7** with modern conventions
- **PostgreSQL** with pgvector for AI features
- **Redis & Sidekiq** for background processing
- **TailwindCSS** for styling
- **Hotwire** (Turbo & Stimulus) for interactivity

### Optional Modules
- **🔐 Authentication** - Complete user auth with OAuth
- **🤖 AI Integration** - Multi-provider LLM support
- **💳 Billing** - Stripe subscriptions and payments
- **👑 Admin Panel** - User management and system admin
- **📡 API** - JSON:API with OpenAPI documentation
- **📝 CMS/Blog** - Content management and blogging
- **🚀 Deployment** - Platform-specific deploy configs

## 📖 Popular Documentation Paths

### For New Users
1. [README](../README.md) → Quick start
2. [Bootstrap CLI](modules/BOOTSTRAP_CLI.md) → Setup guidance
3. [Usage Guide](guides/USAGE.md) → Detailed usage

### For Developers
1. [Contributing](guides/AGENTS.md) → Development guidelines
2. [Implementation Guides](implementation/) → Technical details
3. [Module Documentation](modules/) → Feature-specific docs

### For AI Features
1. [AI Module](modules/ai.md) → LLM integration
2. [System Prompts](modules/SYSTEM_PROMPTS.md) → Prompt management
3. [Agent Implementation](implementation/AGENT_IMPLEMENTATION_SUMMARY.md) → Technical details

## 🆘 Getting Help

1. **CLI Help**: Run `bin/synth help` for command reference
2. **System Check**: Run `bin/synth doctor` to diagnose issues
3. **Module Info**: Run `bin/synth info MODULE_NAME` for specific help
4. **Documentation**: Browse the organized docs in this directory

## 📋 What's New

See [CHANGELOG](CHANGELOG.md) for recent updates and changes.

---

**Ready to dive in?** Start with the [main README](../README.md) or run `bin/synth bootstrap` to get started! 🚀