# Rails Starter Documentation

This documentation is auto-generated from installed Synth modules and OpenAPI specifications.

## Overview

This Rails SaaS application is built using the Rails SaaS Starter Template with the following installed modules:

- **Admin**: This module adds a comprehensive admin panel to your Rails SaaS application with advanced administrative features for...
- **Ai**: This module adds first‑class AI integration to your Rails app with versioned prompt templates, variable interpolation...
- **Api**: Provides JSON:API compliant endpoints and automatic OpenAPI schema generation for Rails SaaS Starter applications.
- **Auth**: This module provides comprehensive authentication features including user registration, login, OAuth integration, and...
- **Deploy**: This module provides deployment configurations and CI/CD setups for three popular platforms:
- **Mcp**: This module provides a flexible context provider system for enriching AI prompts with dynamic data from databases, AP...
- **Theme**: A comprehensive theming framework for customizing colors, fonts, logos, and branding elements in your Rails SaaS appl...

## Quick Start

### Prerequisites

- Ruby 3.3.0 or later
- Node.js 18 or later
- PostgreSQL 14+ with pgvector extension
- Redis 6 or later

### Installation

```bash
# Clone and setup
git clone <repository-url>
cd <app-name>
bundle install
yarn install

# Database setup
rails db:create
rails db:migrate
rails db:seed

# Start development server
bin/dev
```

## Module Documentation

- [Admin](modules/admin.md)
- [Ai](modules/ai.md)
- [Api](modules/api.md)
- [Auth](modules/auth.md)
- [Deploy](modules/deploy.md)
- [Mcp](modules/mcp.md)
- [Theme](modules/theme.md)

## API Documentation

This application provides a JSON:API compliant REST API. 

- **OpenAPI Specification**: [api.json](api.json)
- **API Module Documentation**: [modules/api.md](modules/api.md)

### Authentication

Most API endpoints require authentication using Bearer tokens.

### Base URL

- Development: `http://localhost:3000/api`
- Production: `https://your-domain.com/api`


## Synth CLI

Use the Synth CLI to manage modules:

```bash
# List available modules
bin/synth list

# Add new modules
bin/synth add [module_name]

# Remove modules
bin/synth remove [module_name]

# Generate documentation
bin/synth docs
```

---

*Documentation generated on 2025-07-27 10:13:42 by `bin/synth docs`*
