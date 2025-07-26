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

   cd myapp
   
   # Boot the application
   bin/setup
   bin/dev
   ```

   The `--dev` flag uses Rails Edge.  The template script will install TailwindCSS, set up the database, integrate Sidekiq, configure Devise/OmniAuth, and scaffold a default workspace/team model.

3. **Explore `bin/synth`.**  The CLI tool allows you to manage feature modules:

   ```sh
   bin/synth list            # Show installed modules
   bin/synth add ai          # Add AI/LLM support
   bin/synth add billing     # Add Stripe billing
   bin/synth remove cms      # Remove the CMS/blog engine
   bin/synth upgrade         # Pull in latest module versions
   bin/synth test ai         # Run AI tests
   bin/synth doctor          # Validate your setup (environment, database, Redis, keys)
   bin/synth scaffold agent chatbot_support
   ```

4. **Configure your environment.**  Copy `.env.example` to `.env` and fill in secrets for Devise, OmniAuth providers, Stripe API keys, and LLM providers.  Configure your database (`config/database.yml`) and set up Redis.

5. **Validate deployment setup.**  Run `rails deploy:validate_env` to check your configuration, then use `rails deploy:bootstrap` to set up a new environment.

6. **Run the test suite.**  Execute `bin/rails test` (Minitest) or `bundle exec rspec` if you installed RSpec.  The template ships with mocks for external services and ensures that the default install passes all tests.

7. **Deploy to production.**  Choose from Fly.io, Render, or Kamal deployment platforms. See `DEPLOYMENT.md` for complete deployment guides and platform-specific instructions.

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
* **Deployment readiness** with configurations for Fly.io, Render, and Kamal, comprehensive environment management, health checks, and CI/CD workflows.
* **CI/CD** templates for GitHub Actions, plus deployment configs for Fly.io, Render, and Kamal.

### AI system

* **Prompt templates** with versioning, variable interpolation, tags, output types (JSON, Markdown, HTML partial), previews, and diffs.
* **Asynchronous LLM jobs** with Sidekiq: `LLMJob.perform_later(template:, model:, context:, format:)` executes prompts, logs inputs/outputs, handles retries with exponential backoff, and stores results in `LLMOutput`.  Users can give feedback (thumbs up/down), re‑run, or regenerate jobs.
* **Multi‑Context Provider (MCP)** for dynamic prompt context.  Fetch data from database queries, HTTP APIs (GitHub, Slack), file/document parsing, semantic memory via embeddings, and code introspection.  Compose fetchers via `context.fetch(:key, params)` to produce a hash for prompt templates.  Developers can register custom fetchers.

### CLI (`bin/synth`)

The `bin/synth` tool is a Thor‑based CLI that manages modules in the `lib/templates/synth/` directory.  Modules encapsulate features like `auth`, `billing`, `ai`, `mcp`, `cms`, `admin`, `deploy`, `testing`, `api`, and `docs`.  Each module includes installation scripts, migrations, seeds, and a README.  The CLI logs its actions to `log/synth.log` and provides commands to scaffold new agents for AI features.

### Testing

The template encourages full test coverage.  Every module ships with unit, integration, and system tests.  External services (OpenAI, Claude, Stripe, GitHub) are stubbed to ensure deterministic runs.  The GitHub Actions workflow (`.github/workflows/test.yml`) installs the template into a fresh app and runs the full suite across a matrix of Ruby and PostgreSQL versions.

### Seeding

Seed data sets up a demo organisation with a user, example prompt templates, example LLM jobs and outputs, dummy Stripe plans, and a sample blog post.  Seeds are idempotent, meaning you can run them multiple times without duplicating data.

## Contributing

Contributions are welcome!  Please read **AGENTS.md** for detailed instructions on picking tasks, planning, implementing, testing, and verifying work.  In short:

1. Pick an open issue from the project board.
2. Create a branch and implement the feature with tests.
3. Keep commits small and focused; follow established patterns.
4. Update documentation where needed.
5. Open a PR, link it to the issue, and request review.

## License

This project is provided under the [MIT License](LICENSE).  See `LICENSE` for details.
