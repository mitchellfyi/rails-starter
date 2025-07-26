# Documentation Index

Welcome to the Rails SaaS Starter Template documentation. This comprehensive guide will help you understand, configure, and extend the template for your AI-native SaaS application.

## Getting Started

- **[Main README](../README.md)** - Project overview, installation, and quick start
- **[Configuration Guide](CONFIGURATION.md)** - Environment setup and module configuration
- **[Testing Strategy](TESTING.md)** - How to run tests and testing best practices

## Core Documentation

### Development
- **[Contributing Modules](CONTRIBUTING_MODULES.md)** - How to create new feature modules
- **[AGENTS.md](../AGENTS.md)** - General contribution guidelines and workflow

### API Reference
- **[API Documentation](api/README.md)** - Complete REST API reference
- **[OpenAPI Schema](api/)** - Interactive API documentation

### Module Documentation
- **[AI Module](../scaffold/lib/templates/synth/ai/README.md)** - AI integration and LLM features
- **Billing Module** - Stripe integration and subscription management
- **CMS Module** - Content management system features
- **Admin Module** - Administrative interface and tools

## Reference

### Project Structure
```
rails-starter/
├── README.md                   # Main project documentation
├── CHANGELOG.md               # Version history and changes
├── AGENTS.md                  # Contribution guidelines
├── scaffold/                  # Template files for new apps
│   ├── template.rb           # Main template script
│   ├── bin/synth             # CLI tool
│   └── lib/                  # Module system
│       ├── synth/cli.rb      # CLI implementation
│       └── templates/synth/   # Feature modules
│           └── ai/           # AI module example
└── docs/                     # Documentation
    ├── README.md             # This file
    ├── CONFIGURATION.md      # Configuration guide
    ├── TESTING.md           # Testing documentation
    ├── CONTRIBUTING_MODULES.md # Module development guide
    └── api/                  # API documentation
        └── README.md         # API reference
```

### CLI Commands Reference
```bash
# Core commands
bin/synth help              # Show all commands with descriptions
bin/synth list              # List installed modules
bin/synth doctor            # Validate setup and configuration

# Module management
bin/synth add MODULE        # Install a feature module
bin/synth remove MODULE     # Remove a feature module
bin/synth upgrade          # Update all installed modules

# Development
bin/synth test [MODULE]     # Run tests (all or specific module)
bin/synth scaffold agent NAME  # Create new AI agent

# Examples
bin/synth add ai           # Add AI/LLM capabilities
bin/synth add billing      # Add Stripe billing
bin/synth test ai          # Run AI module tests
bin/synth scaffold agent email_writer  # Create email AI agent
```

### Module System

The template uses a modular architecture where features are organized as self-contained modules:

```
lib/templates/synth/MODULE_NAME/
├── install.rb          # Installation script
├── remove.rb           # Removal script (optional)
├── README.md          # Module documentation
├── app/               # Rails application code
├── config/            # Configuration files
├── migrations/        # Database migrations
├── spec/ or test/     # Tests
└── lib/               # Module-specific libraries
```

**Available Modules:**
- **ai** - AI integration with prompt templates and LLM jobs
- **billing** - Stripe billing and subscription management
- **cms** - Content management system with blog engine
- **admin** - Administrative interface and tools
- **api** - JSON:API endpoints with OpenAPI documentation
- **deploy** - Deployment configurations for various platforms

## Quick Navigation

### For New Users
1. Start with the [Main README](../README.md) for installation
2. Follow the [Configuration Guide](CONFIGURATION.md) for setup
3. Explore modules with `bin/synth help` and `bin/synth list`

### For Developers
1. Review [AGENTS.md](../AGENTS.md) for contribution workflow
2. Read [Contributing Modules](CONTRIBUTING_MODULES.md) for module development
3. Check [Testing Strategy](TESTING.md) for testing guidelines
4. Use [API Documentation](api/README.md) for integration

### For DevOps/Deployment
1. Follow [Configuration Guide](CONFIGURATION.md) for environment setup
2. Review deployment configurations in module documentation
3. Check [Testing Strategy](TESTING.md) for CI/CD setup

## External Resources

### Community
- **GitHub Repository**: [mitchellfyi/rails-starter](https://github.com/mitchellfyi/rails-starter)
- **Issues & Feature Requests**: [GitHub Issues](https://github.com/mitchellfyi/rails-starter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitchellfyi/rails-starter/discussions)

### Dependencies
- **Rails Edge**: Latest Rails features and improvements
- **PostgreSQL + pgvector**: Vector database for AI features
- **Redis + Sidekiq**: Background job processing
- **Hotwire**: Modern frontend with Turbo and Stimulus
- **TailwindCSS**: Utility-first CSS framework

### Related Projects
- **Ruby on Rails**: [rubyonrails.org](https://rubyonrails.org)
- **pgvector**: [pgvector/pgvector](https://github.com/pgvector/pgvector)
- **Sidekiq**: [sidekiq.org](https://sidekiq.org)
- **Hotwire**: [hotwired.dev](https://hotwired.dev)

## Version Information

- **Current Version**: See [CHANGELOG.md](../CHANGELOG.md)
- **Rails Version**: Rails Edge (latest development version)
- **Ruby Version**: 3.2+
- **Node.js Version**: 18+

## License

This template is provided under the [MIT License](../LICENSE). See the license file for details.

---

## Help & Support

### Getting Help
1. **Check Documentation**: Start with this documentation index
2. **Search Issues**: Look for similar issues on GitHub
3. **Run Diagnostics**: Use `bin/synth doctor` to check your setup
4. **Community Support**: Ask questions in GitHub Discussions

### Reporting Issues
1. **Check Existing Issues**: Search for similar problems
2. **Provide Details**: Include error messages, environment info, and steps to reproduce
3. **Minimal Reproduction**: Create a minimal example that demonstrates the issue
4. **Use Templates**: Follow the issue templates for bug reports and feature requests

### Contributing
1. **Read Guidelines**: Review [AGENTS.md](../AGENTS.md) and [Contributing Modules](CONTRIBUTING_MODULES.md)
2. **Start Small**: Begin with documentation improvements or small bug fixes
3. **Follow Patterns**: Use existing code and module patterns as examples
4. **Test Thoroughly**: Ensure all tests pass and add tests for new features

---

*This documentation is continuously updated. For the latest information, always refer to the main repository.*