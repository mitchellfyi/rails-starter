# Rails SaaS Starter Template

This project is a fully‑featured template for building AI‑native SaaS applications on top of **Rails Edge**.  It combines a production‑ready base stack with modular features, long‑term maintainability, and first‑class support for large language models (LLMs).  You can bootstrap a new application with a single command and extend it via a clean CLI.

## Why another template?

Most Rails templates are either toy examples or opinionated stacks that become brittle over time.  This template is designed for serious engineers who need:

* **Production‑grade defaults** (PostgreSQL, pgvector, Sidekiq, Redis, Devise, OmniAuth, JSON:API, OpenAPI, CI/CD, deploy configs);
* **AI‑native support** with prompt templates, an asynchronous LLM job system, and a multi‑context provider (MCP) for enriching prompts;
* **Modular architecture** that allows you to add or remove features cleanly via a command‑line tool (`bin/synth`);
* **Comprehensive tests** that ensure the generated app boots and passes its suite out of the box;
* **Extensibility** to suit real‑world product requirements without rewriting the core.

## Getting started

1. **Install prerequisites.**  You’ll need a recent Ruby (matching Rails Edge), Node.js/Yarn, PostgreSQL (with the `pgvector` extension), Redis, and Fly.io or Render CLI if you plan to deploy.
2. **Create your app.**  Run:

   ```bash
   rails new myapp --dev -m https://raw.githubusercontent.com/mitchellfyi/rails-starter/main/scaffold/template.rb
   cd myapp
   
   # Boot the application
   bin/setup
   bin/dev
   ```

   The `--dev` flag uses Rails Edge.  The template script will install TailwindCSS, set up the database, integrate Sidekiq, configure Devise/OmniAuth, and scaffold a default workspace/team model.

3. **Explore `bin/synth`.**  The CLI tool allows you to manage feature modules:

   ```bash
   bin/synth help              # Show all available commands with descriptions
   bin/synth list              # Show installed modules
   bin/synth add ai            # Add AI/LLM support
   bin/synth add billing       # Add Stripe billing
   bin/synth add cms           # Add CMS/blog engine
   bin/synth remove cms        # Remove the CMS/blog engine
   bin/synth upgrade           # Pull in latest module versions
   bin/synth test ai           # Run AI tests
   bin/synth doctor            # Validate your setup (keys, MCP fetchers)
   bin/synth scaffold agent chatbot_support  # Create AI agent
   ```

4. **Configure your environment.**  Copy `.env.example` to `.env` and fill in secrets for Devise, OmniAuth providers, Stripe API keys, and LLM providers.  Configure your database (`config/database.yml`) and set up Redis.

5. **Run the test suite.**  Execute `bin/rails test` (Minitest) or `bundle exec rspec` if you installed RSpec.  The template ships with mocks for external services and ensures that the default install passes all tests.

## Troubleshooting

### Common Issues

**"Thor not found" error:**
```bash
# Install Thor gem system-wide
sudo apt install ruby-thor  # Ubuntu/Debian
gem install thor             # Alternative if you have gem permissions
```

**Database connection errors:**
```bash
# Ensure PostgreSQL is running and pgvector is installed
sudo apt install postgresql-16-pgvector  # Ubuntu/Debian
createdb myapp_development
```

**Redis connection errors:**
```bash
# Start Redis service
sudo systemctl start redis-server
# Or install Redis
sudo apt install redis-server
```

**Missing environment variables:**
```bash
# Copy and configure environment file
cp .env.example .env
# Edit .env with your API keys and database credentials
```

### Getting Help

- Check the [CHANGELOG.md](CHANGELOG.md) for recent changes
- Review module-specific documentation in `lib/templates/synth/`
- Run `bin/synth doctor` to validate your setup
- Open an issue on GitHub for bugs or feature requests

## Features

### Base stack

* **Rails Edge** (`--dev`) with Hotwire (Turbo & Stimulus) and TailwindCSS.
* **PostgreSQL** with `pgvector` extension for semantic embeddings.
* **Redis & Sidekiq** for background job processing.
* **Devise** for email/password authentication with confirmation, lockout, two‑factor support.
* **OmniAuth** for OAuth logins (Google, GitHub, Slack).
* **Workspaces/teams** with slug routing, invitation system, and role/permission management.
* **JSON:API‑compliant APIs** with automatically generated **OpenAPI** schema.
* **Stripe billing** with free trials, subscriptions, metered billing, coupons, one‑off charges, and PDF invoices.
* **CMS/blog engine** powered by ActionText with WYSIWYG editor, SEO metadata, and sitemap generation.
* **Admin panel** with impersonation, audit logs, Sidekiq UI, and feature flag toggles.
* **Internationalisation** (i18n) with locale detection, right‑to‑left support, and currency/date formatting.
* **CI/CD** templates for GitHub Actions, plus deployment configs for Fly.io, Render, and Kamal.

### AI system

* **Prompt templates** with versioning, variable interpolation, tags, output types (JSON, Markdown, HTML partial), previews, and diffs.
* **Asynchronous LLM jobs** with Sidekiq: `LLMJob.perform_later(template:, model:, context:, format:)` executes prompts, logs inputs/outputs, handles retries with exponential backoff, and stores results in `LLMOutput`.  Users can give feedback (thumbs up/down), re‑run, or regenerate jobs.
* **Multi‑Context Provider (MCP)** for dynamic prompt context.  Fetch data from database queries, HTTP APIs (GitHub, Slack), file/document parsing, semantic memory via embeddings, and code introspection.  Compose fetchers via `context.fetch(:key, params)` to produce a hash for prompt templates.  Developers can register custom fetchers.

### CLI (`bin/synth`)

The `bin/synth` tool is a Thor‑based CLI that manages modules in the `lib/templates/synth/` directory.  Modules encapsulate features like `ai`, `billing`, `cms`, `admin`, `deploy`, `testing`, `api`, and `docs`.  Each module includes installation scripts, migrations, seeds, and a README.  The CLI logs its actions to `log/synth.log` and provides commands to scaffold new agents for AI features.

**Key Commands:**
- `bin/synth help` - Show all commands with detailed descriptions
- `bin/synth add MODULE` - Install feature modules (ai, billing, cms, admin)
- `bin/synth list` - Show installed modules and versions
- `bin/synth doctor` - Validate setup, API keys, and configuration
- `bin/synth test [MODULE]` - Run tests for all modules or specific module
- `bin/synth scaffold agent NAME` - Create new AI agents

For complete CLI documentation and examples, see the [Documentation Index](docs/README.md).

### Testing

The template encourages full test coverage.  Every module ships with unit, integration, and system tests.  External services (OpenAI, Claude, Stripe, GitHub) are stubbed to ensure deterministic runs.  The GitHub Actions workflow (`.github/workflows/test.yml`) installs the template into a fresh app and runs the full suite across a matrix of Ruby and PostgreSQL versions.

### Seeding

Seed data sets up a demo organisation with a user, example prompt templates, example LLM jobs and outputs, dummy Stripe plans, and a sample blog post.  Seeds are idempotent, meaning you can run them multiple times without duplicating data.

## Contributing

Contributions are welcome!  Please read **[AGENTS.md](AGENTS.md)** for detailed instructions on picking tasks, planning, implementing, testing, and verifying work.  

### Quick Start for Contributors
1. Pick an open issue from the [project board](https://github.com/users/mitchellfyi/projects/2)
2. Create a branch and implement the feature with tests
3. Keep commits small and focused; follow established patterns
4. Update documentation where needed
5. Open a PR, link it to the issue, and request review

### Documentation
- **[Documentation Index](docs/README.md)** - Complete documentation overview
- **[Module Development Guide](docs/CONTRIBUTING_MODULES.md)** - How to create new modules  
- **[Testing Strategy](docs/TESTING.md)** - Testing guidelines and CI setup
- **[API Documentation](docs/api/README.md)** - Complete REST API reference
- **[Configuration Guide](docs/CONFIGURATION.md)** - Environment and module setup

### Module System
Create new features as self-contained modules using `bin/synth`. See the [Module Development Guide](docs/CONTRIBUTING_MODULES.md) for detailed instructions.

## License

This project is provided under the [MIT License](LICENSE).  See `LICENSE` for details.
