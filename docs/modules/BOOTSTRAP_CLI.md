# Interactive Bootstrap CLI

The Rails SaaS Starter now includes an interactive Bootstrap CLI wizard that walks developers through initial setup with clear, interactive prompts.

## Usage

Run the interactive bootstrap wizard:

```bash
./bin/railsplan bootstrap
```

### Command Options

- `--skip-modules`: Skip module selection and install no additional modules
- `--skip-credentials`: Skip API credentials setup
- `--verbose`: Enable verbose output during setup

### What the Bootstrap Wizard Does

The wizard collects the following information through interactive prompts:

#### 1. Application Configuration
- **App name**: The name of your SaaS application
- **Domain**: Your application's domain (e.g., myapp.com)
- **Environment**: Target environment (development, staging, production)

#### 2. Team Configuration
- **Team name**: Your organization or team name
- **Owner email**: Admin user email address
- **Admin password**: Automatically generated secure password for admin access

#### 3. Module Selection
Choose which optional modules to install:
- **ai**: AI-powered features with LLM integration
- **billing**: Stripe integration for subscriptions and payments
- **cms**: Content management system
- **admin**: Admin panel and management tools

#### 4. API Credentials
Prompts for credentials based on selected modules:
- **Stripe**: Publishable key, secret key, webhook secret (for billing)
- **OpenAI**: API key and organization ID (for AI features)
- **GitHub**: OAuth client ID/secret and personal access token
- **SMTP**: Email configuration for transactional emails

#### 5. AI Configuration
If AI modules are selected:
- **LLM Provider**: Choose between OpenAI, Anthropic, Cohere, or Hugging Face

## Generated Files

### .env File
The wizard generates a complete `.env` file with:
- Rails configuration (SECRET_KEY_BASE, RAILS_ENV)
- Application settings (APP_NAME, APP_HOST)
- Database configuration
- API credentials for selected services
- Feature flags for installed modules

### db/seeds.rb
Generates seed data including:
- Admin user with provided email and generated password
- Default team/organization
- Initial configuration for installed modules

## Example Usage

```bash
$ ./bin/railsplan bootstrap

🚀 Welcome to Rails SaaS Starter Bootstrap Wizard!
============================================================

🔧 Application Configuration
------------------------------
Application name [Rails SaaS Starter]: MyAwesome SaaS
Domain (e.g., myapp.com) [localhost:3000]: myawesome.com
Environment:
  1. development (default)
  2. staging
  3. production
Select (1-3): 3

👥 Team Configuration
--------------------
Team/Organization name [My Team]: Awesome Team
Owner email address [admin@myawesome.com]: admin@myawesome.com
   Generated admin password: SecurePassword123!

📦 Module Selection
------------------
Available modules:
  1. ai              - AI-powered features and integrations
  2. billing         - Stripe integration for subscriptions
  3. cms             - Content management system
  4. admin           - Admin panel and management tools
  5. Install all modules
  6. Skip module installation
Select modules (comma-separated numbers): 1,2,3

🔑 API Credentials
-----------------
💳 Stripe Configuration (for billing):
Stripe publishable key (pk_test_...): pk_live_...
Stripe secret key (sk_test_...): sk_live_...
Stripe webhook secret (whsec_...): whsec_...

🤖 OpenAI Configuration:
OpenAI API key (sk-...): sk-...
OpenAI Organization ID (optional): org-...

🤖 AI Configuration
------------------
Preferred LLM provider:
  1. openai (default)
  2. anthropic
  3. cohere
  4. huggingface
Select (1-4): 1

🔧 Setting up application...
   📝 Generating .env file...
   ✅ .env file created
   📦 Installing selected modules...
      Installing ai...
      ✅ Successfully installed ai module!
      Installing billing...
      ✅ Successfully installed billing module!
      Installing cms...
      ✅ Successfully installed cms module!
   🌱 Generating seed data...
   ✅ Seed data generated
✅ Application setup complete!

🎉 Bootstrap complete! Your Rails SaaS application is ready.
📋 Next steps:
   1. Review the generated .env file and add any missing credentials
   2. Run: rails db:create db:migrate db:seed
   3. Start your application: rails server
   4. Access admin panel: http://myawesome.com/admin
      Email: admin@myawesome.com
      Password: SecurePassword123!
```

## Post-Bootstrap Steps

After running the bootstrap wizard:

1. **Review .env file**: Check the generated `.env` file and ensure all credentials are correct
2. **Setup database**: Run `rails db:create db:migrate db:seed`
3. **Start application**: Run `rails server` to start your SaaS application
4. **Access admin panel**: Log in with the generated admin credentials
5. **Customize**: Begin customizing your application for your specific use case

## Integration with Existing CLI

The bootstrap command integrates seamlessly with the existing Synth CLI:

- Uses the same module system for installing features
- Leverages existing templates and configurations
- Maintains compatibility with other CLI commands
- Follows the same logging and error handling patterns

## Security Considerations

- Admin passwords are generated using `SecureRandom.alphanumeric(16)`
- Sensitive credentials are only stored in the `.env` file (not committed to version control)
- The wizard validates input and provides secure defaults
- Generated seed data uses Rails' secure password handling

## Demo

Run the demo script to see what the bootstrap output looks like:

```bash
ruby demo_bootstrap.rb
```