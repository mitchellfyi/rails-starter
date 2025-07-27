# Module Documentation Index

This directory contains documentation for individual modules in the Rails SaaS Starter Template.

## Available Modules

### Core Modules
- **[AI Module](../scaffold/lib/templates/railsplan/ai/README.md)** - AI integration with prompt templates and LLM jobs
- **Billing Module** - Stripe integration and subscription management *(Coming soon)*
- **CMS Module** - Content management system with blog engine *(Coming soon)*
- **Admin Module** - Administrative interface and tools *(Coming soon)*

### Infrastructure Modules
- **API Module** - JSON:API endpoints with OpenAPI documentation *(Coming soon)*
- **Deploy Module** - Deployment configurations for various platforms *(Coming soon)*
- **Testing Module** - Enhanced testing tools and utilities *(Coming soon)*

## Module Structure

Each module follows a consistent structure:

```
lib/templates/railsplan/module_name/
├── README.md          # Module documentation
├── install.rb         # Installation script
├── remove.rb          # Removal script (optional)
├── app/              # Rails application code
├── config/           # Configuration files
├── migrations/       # Database migrations
├── spec/ or test/    # Tests
└── lib/              # Module-specific libraries
```

## Creating Module Documentation

When creating a new module, use the [AI Module README](../scaffold/lib/templates/railsplan/ai/README.md) as a template. Include:

1. **Overview** - What the module provides
2. **Features** - Key capabilities and benefits
3. **Installation** - How to install via `bin/railsplan add`
4. **Configuration** - Required settings and environment variables
5. **Usage** - Code examples and common patterns
6. **API Endpoints** - REST API documentation (if applicable)
7. **Testing** - How to run module-specific tests
8. **Customization** - Extension points and customization options
9. **Troubleshooting** - Common issues and solutions
10. **Removal** - How to safely remove the module

## Documentation Standards

- Use clear, practical examples
- Include code snippets for common use cases
- Document all configuration options
- Provide troubleshooting sections
- Keep documentation up-to-date with code changes
- Follow markdown best practices for formatting

For more information on creating modules, see the [Module Development Guide](../CONTRIBUTING_MODULES.md).