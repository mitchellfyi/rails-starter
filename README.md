# Rails SaaS Starter Template

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-3.4.2-red.svg)](https://ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-edge%20%7C%208.0+-green.svg)](https://rubyonrails.org)

A **Rails application generator** that creates production-ready SaaS applications with AI capabilities, billing, admin panels, and more. Think of it as a "Rails new" command that gives you a complete SaaS foundation.

> **💡 This project is free to use!** If you find it valuable, consider [supporting development](https://mitchell.fyi) to help keep it cutting-edge.

## 🎯 What This Actually Is

This is a **Rails template** - a script that generates a new Rails application with all the SaaS features you need already built-in. It's like having a team of developers set up your entire application architecture for you.

### How It Works
1. **Generate** a new Rails app with this template
2. **Get** a complete SaaS application with authentication, billing, AI features, etc.
3. **Customize** by adding/removing modules as needed
4. **Deploy** to your preferred platform

## 🚀 Getting Started

### Step 1: Generate Your Application

```bash
# Create a new Rails app using this template
rails new my-saas-app --dev -m https://github.com/mitchellfyi/rails-starter/raw/main/scaffold/template.rb
```

**What happens:**
- Creates a new Rails application using Rails edge (latest features)
- Works with Ruby >= 3.3.0 (supports Ruby 3.3.x, 3.4.x, etc.)
- Installs all necessary gems (PostgreSQL, Redis, Devise, etc.)
- Sets up authentication, multi-tenancy, and core features
- Installs the `bin/railsplan` CLI for managing modules
- Creates your first commit

### Step 2: Set Up Your Environment

```bash
cd my-saas-app

# Copy environment variables and configure
cp .env.example .env
# Edit .env with your actual API keys and settings

# Set up the database
bin/rails db:create db:migrate db:seed

# Start the development server
bin/rails server
```

Visit `http://localhost:3000` and you'll have a working SaaS application!

## 🏗️ What You Get Out of the Box

### Core Features (Always Included)
- ✅ **User Authentication** - Devise with email/password and OAuth
- ✅ **Multi-tenancy** - Workspaces and team management
- ✅ **Admin Panel** - User management, audit logs, feature flags
- ✅ **API Layer** - JSON:API with auto-generated documentation
- ✅ **Background Jobs** - Sidekiq for async processing
- ✅ **Modern Frontend** - Hotwire (Turbo + Stimulus) + TailwindCSS
- ✅ **Latest Rails Features** - Built on Rails edge for cutting-edge functionality

### Optional Modules (Install as needed)
- 🤖 **AI Integration** - LLM providers, prompt management, async jobs
- 💳 **Stripe Billing** - Subscriptions, metered billing, invoices
- 📝 **CMS/Blog** - Content management with SEO
- 🌍 **Internationalization** - Multi-language support
- 🚀 **Deployment** - Configs for Fly.io, Render, Kamal

## 🔧 Managing Your Application

### The `bin/railsplan` CLI

This is your main tool for managing the application:

```bash
# See what's available
bin/railsplan list

# Install a module
bin/railsplan add billing

# Remove a module
bin/railsplan remove cms

# Check your setup
bin/railsplan doctor

# Run tests
bin/railsplan test
```

### Available Modules

| Module | What It Adds | When to Use |
|--------|-------------|-------------|
| `auth` | User authentication | Always included |
| `billing` | Stripe subscriptions & billing | When you need to charge users |
| `ai` | AI/LLM integration | When you need AI features |
| `admin` | Admin panel & management | Always included |
| `api` | JSON:API endpoints | When you need an API |
| `cms` | Blog/content management | When you need a blog |
| `deploy` | Deployment configurations | When ready to deploy |

## 📚 Understanding the Architecture

### Domain-Driven Structure
Your app is organized by business domains:

```
app/domains/
├── auth/          # Authentication & users
├── billing/       # Payments & subscriptions  
├── ai/           # AI features & LLM integration
├── admin/        # Admin panel & management
└── api/          # API endpoints
```

Each domain is self-contained with its own:
- Models and migrations
- Controllers and views
- Tests and documentation
- Configuration

### Why This Structure?
- **Maintainable** - Each feature is isolated
- **Scalable** - Easy to add/remove features
- **Testable** - Each domain can be tested independently
- **Team-friendly** - Different developers can work on different domains

## 🛠️ Development Workflow

### Adding a New Feature

1. **Install the module:**
   ```bash
   bin/railsplan add billing
   ```

2. **Configure it:**
   ```bash
   # Edit config/initializers/billing.rb
   # Add your Stripe keys to .env
   ```

3. **Customize as needed:**
   ```bash
   # The module files are in app/domains/billing/
   # Edit models, controllers, views as needed
   ```

### Removing a Feature

```bash
bin/railsplan remove cms
# This removes the CMS module and all its files
```

## 🚀 Deployment

### Quick Deploy to Fly.io

```bash
# Install deployment module
bin/railsplan add deploy

# Deploy
fly deploy
```

### Other Platforms
- **Render** - `render deploy`
- **Heroku** - `git push heroku main`
- **Self-hosted** - Use the Kamal configuration

## 🧪 Testing

```bash
# Run all tests
bin/rails test

# Test a specific module
bin/railsplan test billing

# Check system health
bin/railsplan doctor
```

## 📖 Documentation

- **[Module Guides](docs/modules/)** - Detailed docs for each feature
- **[Implementation Details](docs/implementation/)** - Technical deep-dives
- **[Admin Panel](docs/admin/)** - Admin features guide
- **[API Documentation](docs/api/)** - API endpoints and usage
- **[Rails Version Strategy](docs/RAILS_VERSION_STRATEGY.md)** - Understanding Rails edge vs stable
- **[Support This Project](docs/SUPPORT.md)** - Fairware model and contribution options

## 🤔 Common Questions

### "Is this a framework?"
No, it's a **template** that generates a Rails application. You get a normal Rails app that you can modify however you want.

### "Can I use this for existing apps?"
This template is designed for **new applications**. For existing apps, you'd need to manually integrate the features you want.

### "What if I don't need AI features?"
Just don't install the AI module! Each feature is optional and can be added/removed as needed.

### "How do I customize the styling?"
The app uses TailwindCSS. Edit `app/assets/stylesheets/application.css` and the Tailwind config files.

### "Can I use a different database?"
Yes! The template defaults to PostgreSQL but you can switch to MySQL, SQLite, etc. Just update your `config/database.yml`.

### "How do I switch from Rails edge to Rails 8 stable?"
Edit your `Gemfile` and comment out the edge line, then uncomment the stable line:
```ruby
# Use Rails edge (main branch) by default, with Rails 8 as fallback
# gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 8.0.0'
```
Then run `bundle update rails` to switch versions.

### "What Ruby version do I need?"
The template recommends Ruby 3.4.2 for optimal compatibility and performance. It supports Ruby >= 3.4.0, but Ruby 3.4.2 is the recommended version for the best experience.

## 🆘 Getting Help

1. **Check the docs** - Start with the module documentation
2. **Run `bin/railsplan doctor`** - Diagnose common issues
3. **Look at the tests** - They show how features are supposed to work
4. **Check the example apps** - See how features are used in practice

## 🎉 Next Steps

1. **Generate your app** using the template
2. **Explore the code** - Look at `app/domains/` to see how features are organized
3. **Install modules** you need with `bin/railsplan add`
4. **Customize** the styling and branding
5. **Deploy** when ready!

---

**Ready to build your SaaS?** Start with `rails new myapp --dev -m [template-url]`! 🚀

## ❤️ Support This Project

This project is free to use for any purpose, personal or commercial.

However, if you're building a business with it—or simply find it valuable—please consider supporting development:

**→ [Pay What You Want](https://mitchell.fyi)**  
Even small contributions help keep the project alive and growing.

### Suggested Tiers
- **$0**: Hobby / student projects
- **$50**: Solo developer / freelancer
- **$200**: Startup / small business
- **$500+**: Enterprise / large company

### Why Support?
- 🚀 **Keep it cutting-edge**: Help maintain Rails edge compatibility
- 🐛 **Bug fixes**: Faster resolution of issues
- 📚 **Documentation**: Better guides and examples
- 🔧 **New features**: More modules and integrations
- 💡 **Community**: Support the open-source ecosystem

*Every contribution, no matter the size, makes a difference!*