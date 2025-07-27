# Domain Architecture

This Rails SaaS Starter Template uses a domain-driven architecture to organize code into logical business domains. This approach improves separation of concerns and allows teams to work in parallel on different domains.

## Architecture Overview

### Models
All models are centralized in the standard Rails location:
- **Location**: `/app/models/`
- **Reasoning**: Models represent the core data layer and are often shared across domains
- **Examples**: User, Workspace, Plan, Invoice, Notification, etc.

### Domain-Specific Logic
Controllers, services, jobs, mailers, and other business logic are organized by domain:
- **Location**: `/app/domains/{domain_name}/app/`
- **Structure**:
  ```
  app/domains/{domain}/
  ├── app/
  │   ├── controllers/     # Domain-specific controllers
  │   ├── services/        # Domain business logic
  │   ├── jobs/           # Background jobs for this domain
  │   ├── mailers/        # Domain-specific mailers
  │   ├── policies/       # Authorization policies
  │   ├── queries/        # Complex query objects
  │   └── views/          # Domain-specific views
  └── README.md           # Domain documentation
  ```

### Tests
Tests are organized to match the code structure:
- **Models**: `/spec/models/` (standard Rails location)
- **Domain Logic**: `/spec/domains/{domain_name}/`

## Available Domains

| Domain | Purpose | Key Components |
|--------|---------|----------------|
| `auth` | Authentication & authorization | Sessions, OmniAuth, 2FA |
| `billing` | Payment processing | Stripe integration, subscriptions |
| `workspace` | Team management | Workspaces, memberships, invitations |
| `ai` | AI/LLM functionality | Prompt templates, AI jobs |
| `cms` | Content management | Posts, pages, categories |
| `notifications` | Messaging system | In-app & email notifications |
| `admin` | Administrative functions | User management, audit logs |
| `onboarding` | User onboarding | Step-by-step wizards |

## Using the Architecture

### Creating New Domain Logic

Use the ModularScaffoldGenerator to create domain-specific scaffolds:

```bash
rails generate modular_scaffold Article title:string content:text --domain=cms
```

This creates:
- Model in `/app/models/article.rb`
- Controller in `/app/domains/cms/app/controllers/articles_controller.rb`
- Views in `/app/domains/cms/app/views/articles/`
- Tests in `/spec/domains/cms/`

### Adding Modules

Install domain modules using the Synth CLI:

```bash
bin/railsplan add auth        # Adds authentication domain
bin/railsplan add billing     # Adds billing domain
bin/railsplan add workspace   # Adds workspace domain
```

### Domain Boundaries

Follow these guidelines for clean domain separation:

1. **Models are shared**: Any domain can use any model
2. **Controllers are domain-specific**: Each domain owns its controllers
3. **Services encapsulate business logic**: Keep complex logic in service objects
4. **Cross-domain communication**: Use service objects or events, not direct controller calls

### Example Domain Structure

```
app/domains/billing/
├── app/
│   ├── controllers/
│   │   ├── billing/
│   │   │   ├── subscriptions_controller.rb
│   │   │   ├── invoices_controller.rb
│   │   │   └── webhooks_controller.rb
│   │   └── concerns/
│   ├── services/
│   │   ├── stripe_service.rb
│   │   ├── subscription_service.rb
│   │   └── invoice_generator.rb
│   ├── jobs/
│   │   ├── subscription_renewal_job.rb
│   │   └── invoice_delivery_job.rb
│   └── views/
│       └── billing/
├── README.md
└── VERSION
```

## Benefits

1. **Team Scalability**: Teams can work independently on different domains
2. **Clear Boundaries**: Business logic is grouped by domain responsibility
3. **Easier Testing**: Tests are co-located with domain logic
4. **Modular Development**: Domains can be developed and deployed independently
5. **Reduced Coupling**: Dependencies between domains are explicit

## Migration Guide

If you have existing Rails apps, migrate to this architecture by:

1. Keep models in `/app/models/`
2. Move controllers to appropriate domains: `/app/domains/{domain}/app/controllers/`
3. Move services to domains: `/app/domains/{domain}/app/services/`
4. Update routes to namespace controllers properly
5. Move tests to match the new structure

## Best Practices

1. **Single Responsibility**: Each domain should have a clear, focused purpose
2. **Explicit Dependencies**: Make cross-domain dependencies obvious
3. **Shared Utilities**: Put cross-domain utilities in `/app/services/shared/`
4. **Documentation**: Keep domain README files up-to-date
5. **Testing**: Maintain good test coverage for each domain