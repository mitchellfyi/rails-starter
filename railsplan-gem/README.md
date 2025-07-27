# RailsPlan

**Global CLI for Rails SaaS Bootstrapping**

RailsPlan is a comprehensive command-line tool that generates full-stack, AI-native, production-ready Rails SaaS applications with modular architecture. It replaces the complexity of `rails new -m` with opinionated scaffolding, post-generation processing, and module install capabilities — all optimized for world-class developer experience.

## 🚀 Quick Start

```bash
# Install the gem
gem install railsplan

# Generate a new Rails SaaS application
railsplan new myapp

# Generate with specific modules
railsplan new myapp --ai --billing --admin

# Quick demo setup
railsplan new myapp --demo

# Full guided setup
railsplan new myapp --guided
```

## ✨ Features

### 🎯 **Smart Application Generation**
- **Ruby Version Management**: Automatically detects and ensures compatible Ruby versions
- **Rails Installation**: Installs Rails edge or specific versions as needed
- **Optimal Defaults**: PostgreSQL, Tailwind CSS, and modern Rails configuration
- **Development Ready**: Pre-configured development environment with binstubs

### 🧩 **Modular Architecture**
- **AI Module**: Multi-provider AI integration with LLM job system
- **Billing Module**: Subscription and payment processing with Stripe
- **Admin Module**: Admin panel with user management and analytics
- **CMS Module**: Content management system with rich editing
- **API Module**: RESTful API with automatic documentation
- **Auth Module**: Enhanced authentication and authorization
- **Notifications Module**: Real-time notifications system
- **Workspace Module**: Multi-tenant workspace management

### 🛠 **Developer Experience**
- **Interactive Prompts**: Guided setup with TTY prompts
- **Progress Indicators**: Real-time feedback with spinners and progress bars
- **Comprehensive Logging**: Detailed logs for debugging and auditing
- **Error Handling**: Clear error messages with troubleshooting guidance
- **Configuration Management**: Persistent settings and module registry

## 📦 Installation

### Prerequisites
- Ruby 3.3.0 or higher (3.4.2+ recommended)
- Git
- A Ruby version manager (rbenv, rvm, or asdf) recommended

### Install RailsPlan
```bash
gem install railsplan
```

### Verify Installation
```bash
railsplan version
```

## 🎮 Usage

### Generate New Application

```bash
# Basic generation with interactive prompts
railsplan new myapp

# Generate with specific modules
railsplan new myapp --ai --billing --admin

# Quick demo setup (AI + Billing + Admin)
railsplan new myapp --demo

# Full guided setup for production
railsplan new myapp --guided

# Specify Ruby and Rails versions
railsplan new myapp --ruby-version=3.4.2 --rails-version=edge
```

### Manage Modules

```bash
# List available modules
railsplan list

# Add module to existing application
railsplan add ai

# Remove module from application
railsplan remove cms

# Show module information
railsplan info billing
```

### Diagnostics and Maintenance

```bash
# Run diagnostics
railsplan doctor

# Pass through to Rails CLI
railsplan rails server
railsplan rails console
railsplan rails routes
```

## 🏗 Architecture

### Core Components

- **Generator**: Orchestrates the entire application generation process
- **RubyManager**: Handles Ruby version detection and installation
- **RailsManager**: Manages Rails installation and version compatibility
- **AppGenerator**: Executes Rails application generation
- **ModuleManager**: Installs and manages modular templates
- **Logger**: Provides structured logging throughout the process
- **Config**: Manages configuration and settings

### Module System

Modules are self-contained templates that can be installed into Rails applications:

```
templates/
├── base/           # Base application templates
└── modules/
    ├── ai/         # AI/LLM integration
    ├── billing/    # Subscription and payments
    ├── admin/      # Admin panel
    ├── cms/        # Content management
    ├── auth/       # Authentication
    ├── api/        # RESTful API
    ├── notifications/ # Real-time notifications
    └── workspace/  # Multi-tenant workspaces
```

Each module includes:
- `README.md`: Module documentation
- `VERSION`: Module version
- `install.rb`: Installation script
- `remove.rb`: Removal script (optional)
- Application files (models, controllers, views, etc.)

## 🔧 Configuration

### RailsPlan Configuration File

RailsPlan creates a `.railsplanrc` file in each generated application:

```json
{
  "version": "0.1.0",
  "generated_at": "2024-01-15T10:30:00Z",
  "ruby_version": "3.4.2",
  "rails_version": "edge",
  "installed_modules": ["ai", "billing", "admin"],
  "modules": {
    "ai": {
      "installed_at": "2024-01-15T10:30:00Z",
      "version": "1.0.0"
    }
  }
}
```

### Environment Variables

- `RAILSPLAN_LOG_LEVEL`: Set logging level (DEBUG, INFO, WARN, ERROR, FATAL)
- `RAILSPLAN_TEMPLATE_PATH`: Custom template directory path

## 📚 Module Documentation

### AI Module
Provides comprehensive AI/LLM integration:
- Multi-provider support (OpenAI, Anthropic, Google)
- LLM job system with background processing
- Token usage tracking and cost estimation
- MCP (Model Context Protocol) integration
- Prompt management and versioning

### Billing Module
Handles subscription and payment processing:
- Stripe integration for payments
- Subscription management
- Usage-based billing
- Invoice generation
- Payment webhooks

### Admin Module
Admin panel and user management:
- User administration interface
- Analytics dashboard
- System monitoring
- Audit logging
- Role-based access control

### CMS Module
Content management system:
- Rich text editing
- Media management
- Page templates
- SEO optimization
- Content versioning

## 🧪 Testing

```bash
# Run tests
bundle exec rspec

# Run with coverage
bundle exec rspec --coverage
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Clone the repository
git clone https://github.com/railsplan/railsplan.git
cd railsplan

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Build the gem
gem build railsplan.gemspec

# Install locally
gem install ./railsplan-0.1.0.gem
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [https://railsplan.dev](https://railsplan.dev)
- **Issues**: [GitHub Issues](https://github.com/railsplan/railsplan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/railsplan/railsplan/discussions)
- **Email**: team@railsplan.dev

## 🙏 Acknowledgments

- Rails team for the amazing framework
- Thor team for the excellent CLI framework
- TTY team for the beautiful terminal tools
- All contributors and users

---

**Made with ❤️ for the Rails community** 