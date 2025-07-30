# RailsPlan

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-3.4.2-red.svg)](https://ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-edge%20%7C%208.0+-green.svg)](https://rubyonrails.org)

A **Rails application generator** that creates production-ready SaaS applications with AI capabilities, billing, admin panels, and more. Think of it as a "Rails new" command that gives you a complete SaaS foundation.

> **💡 This project is free to use!** If you find it valuable, consider [supporting development](https://mitchell.fyi) to help keep it cutting-edge.

## 🎯 What This Actually Is

This project provides **two ways** to generate Rails SaaS applications:

### **1. RailsPlan Gem (Global CLI) - RECOMMENDED**
A **global CLI tool** that provides an enhanced experience for generating Rails SaaS applications with interactive prompts, automatic Ruby/Rails setup, and modular feature management.

### **2. Rails Template**
A **Rails template** - a script that generates a new Rails application with all the SaaS features you need already built-in. It's like having a team of developers set up your entire application architecture for you.

**Choose your method:**
- **Recommended**: `railsplan new myapp` (globally installed gem)
- **Alternative**: `rails new myapp --dev -m https://github.com/mitchellfyi/railsplan/raw/main/scaffold/template.rb`

### How It Works
1. **Generate** a new Rails app with this template
2. **Get** a complete SaaS application with authentication, billing, AI features, etc.
3. **Customize** by adding/removing modules as needed
4. **Deploy** to your preferred platform

## 🚀 Getting Started (Recommended: RailsPlan Gem)

### Step 1: Install the RailsPlan Gem
```bash
gem install railsplan
```

### Step 2: Generate Your Application
```bash
# Basic generation
railsplan new my-saas-app

# Generate with specific modules
railsplan new my-saas-app --ai --billing --admin

# Interactive guided setup
railsplan new my-saas-app --guided
```

**What the gem provides:**
- ✅ **Automatic Ruby Setup** - Detects and installs compatible Ruby versions
- ✅ **Rails Installation** - Installs Rails edge or specific versions
- ✅ **Interactive Prompts** - Guided setup with TTY prompts
- ✅ **Module Management** - Easy add/remove of features
- ✅ **Health Checks** - `railsplan doctor` for diagnostics
- ✅ **Progress Feedback** - Real-time status updates

### Step 3: Set Up Your Environment
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

### RailsPlan Commands

```bash
# Generate new app
railsplan new myapp

# AI-powered development commands
railsplan index                                    # Extract Rails app context for AI
railsplan generate "Add a Comment model"           # Generate code with AI
railsplan generate "..." --profile=test           # Use specific AI profile

# Module management
railsplan add ai
railsplan add billing

# Remove modules
railsplan remove cms

# Check app health
railsplan doctor

# List available modules
railsplan list

# Rails CLI passthrough (no need for 'rails' prefix)
railsplan server
railsplan console
railsplan routes
```

## 🔄 Alternative: Using the Rails Template

If you prefer to use the Rails template directly:

### Step 1: Generate Your Application
```bash
# Create a new Rails app using this template
rails new my-saas-app --dev -m https://github.com/mitchellfyi/railsplan/raw/main/scaffold/template.rb
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

## 🤖 AI-Powered Development

RailsPlan now includes **AI-native development workflows** that let you build and scaffold your apps using **natural language**, with zero boilerplate, while maintaining Rails best practices.

### Quick Start with AI

```bash
# 1. Generate your app
railsplan new myapp
cd myapp

# 2. Set up AI credentials
mkdir -p ~/.railsplan
cat > ~/.railsplan/ai.yml << EOF
default:
  provider: openai
  model: gpt-4o
  api_key: <%= ENV['OPENAI_API_KEY'] %>
profiles:
  test:
    provider: anthropic
    model: claude-3-sonnet
    api_key: <%= ENV['CLAUDE_KEY'] %>
EOF

# 3. Index your application context
railsplan index

# 4. Generate code with natural language
railsplan generate "Add a Project model with title, description, and user association"
railsplan generate "Create a blog system with posts and comments"
railsplan generate "Add authentication to the User model"
```

### How AI Generation Works

1. **`railsplan index`** - Extracts your Rails app context (models, schema, routes, controllers) into `.railsplan/context.json`
2. **`railsplan generate "description"`** - Uses AI to generate appropriate Rails code based on your instruction and app context
3. **Preview & Confirm** - Shows you what will be generated before writing any files
4. **Smart Integration** - Ensures naming and structure match your existing codebase

### AI Provider Configuration

#### Option 1: Global Configuration File
```yaml
# ~/.railsplan/ai.yml
default:
  provider: openai
  model: gpt-4o
  api_key: <%= ENV['OPENAI_API_KEY'] %>
profiles:
  claude:
    provider: anthropic
    model: claude-3-sonnet
    api_key: <%= ENV['CLAUDE_KEY'] %>
  gpt35:
    provider: openai
    model: gpt-3.5-turbo
    api_key: <%= ENV['OPENAI_API_KEY'] %>
```

#### Option 2: Environment Variables
```bash
export OPENAI_API_KEY=your_key_here
export RAILSPLAN_AI_PROVIDER=openai
export RAILSPLAN_AI_MODEL=gpt-4o
```

#### Option 3: Project-Specific Configuration
```yaml
# .railsplanrc (in your project root)
ai:
  provider: anthropic
  model: claude-3-sonnet
  api_key: <%= ENV['CLAUDE_KEY'] %>
```

### AI Command Examples

```bash
# Basic model generation
railsplan generate "Add a Product model with name, price, description, and category"

# Complex associations
railsplan generate "Create a Blog system with User, Post, Comment, and Tag models with proper associations"

# Controllers and views
railsplan generate "Add a REST API for Products with JSON responses"

# Authentication features
railsplan generate "Add password reset functionality to User model"

# Use specific AI profile
railsplan generate "Add payment processing" --profile=claude

# Creative mode for more exploratory responses
railsplan generate "Suggest improvements to my User model" --creative

# Force mode (skip confirmation)
railsplan generate "Add basic CRUD for Products" --force
```

### What Gets Generated

The AI can generate:
- **Models** with proper validations, associations, and scopes
- **Migrations** with appropriate database columns and indexes
- **Controllers** with RESTful actions
- **Routes** that follow Rails conventions
- **Views** using Hotwire and TailwindCSS
- **Tests** (RSpec or Minitest)
- **Documentation** and comments

### Context Indexing

The `railsplan index` command extracts:
- **Models**: Class names, associations, validations, scopes
- **Database Schema**: Tables, columns, types, indexes
- **Routes**: HTTP methods, paths, controller actions
- **Controllers**: Class names, action methods
- **Installed Modules**: RailsPlan modules currently installed

This context is used to provide the AI with relevant information about your existing codebase, ensuring generated code integrates seamlessly.

### AI Workflow Features

- **Preview Before Writing**: See exactly what files will be created/modified
- **Interactive Confirmation**: Choose to accept, preview individual files, or modify instructions
- **Prompt Logging**: All AI interactions are logged to `.railsplan/prompts.log` for debugging
- **Error Recovery**: Generated code is saved to `.railsplan/last_generated/` for recovery
- **Fallback Support**: Works without AI (falls back to standard Rails generators)

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

### "The AI generation isn't working"
1. **Check your API key**: Make sure `OPENAI_API_KEY` or `CLAUDE_KEY` is set
2. **Verify configuration**: Run `cat ~/.railsplan/ai.yml` to check your config
3. **Update context**: Run `railsplan index` to refresh your app context
4. **Check logs**: Look at `.railsplan/prompts.log` for AI interaction details
5. **Test connection**: Try with a simple instruction first

### "AI generated code doesn't match my style"
1. **Add style guide**: Include your coding conventions in the project README
2. **Use custom instructions**: Be more specific about formatting and patterns
3. **Modify after generation**: The AI provides a starting point - customize as needed
4. **Configure rubocop**: The AI will try to follow your linting rules if present

### "Context indexing is slow"
1. **Large codebase**: This is normal for apps with many models/controllers
2. **Update only when needed**: Context is cached and only updates when files change
3. **Exclude directories**: You can customize which directories are scanned

## 🆘 Getting Help

1. **Check the docs** - Start with the module documentation
2. **Run `railsplan doctor`** - Diagnose common issues  
3. **Check AI logs** - Look at `.railsplan/prompts.log` for AI-related issues
4. **Test with simple examples** - Try basic AI generation first
5. **Look at the tests** - They show how features are supposed to work
6. **Check the example apps** - See how features are used in practice

## 🎉 Next Steps

1. **Install the RailsPlan gem**: `gem install railsplan`
2. **Generate your app**: `railsplan new myapp`
3. **Set up AI credentials**: Configure `~/.railsplan/ai.yml` with your API keys
4. **Index your app context**: `railsplan index`
5. **Try AI generation**: `railsplan generate "Add a simple blog"`
6. **Explore the code** - Look at `app/domains/` to see how features are organized
7. **Install modules** you need with `railsplan add`
8. **Customize** the styling and branding
9. **Deploy** when ready!

---

**Ready to build your SaaS?** Install the RailsPlan gem and get started! 🚀

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