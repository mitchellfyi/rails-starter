# Developer Onboarding

Welcome to the development team! This guide will help you get up and running.

## Required Tools and Versions

### Core Requirements
- Ruby 3.2.3
- Rails 8.1.0.alpha
- Node.js (>= 18.0)
- npm or yarn

### Database
- PostgreSQL (>= 13) or SQLite 3

### Development Tools
- Git
- Code editor (VS Code, RubyMine, etc.)
- Browser with developer tools

## Setup Process

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. **Install Ruby dependencies**
   ```bash
   bundle install
   ```

3. **Install Node.js dependencies**
   ```bash
   npm install
   ```

4. **Setup environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Setup the database**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

6. **Run tests to verify setup**
   ```bash
   bin/rails test
   ```

7. **Start the development server**
   ```bash
   bin/rails server
   ```

## AI Features and Context System

This application uses RailsPlan's AI-native architecture:

- **Context Management**: The `.railsplan/` directory contains AI context
- **AI Code Generation**: Use `railsplan generate` for AI-powered development
- **Prompt Logging**: All AI interactions are logged for review

### AI Configuration

Configure AI providers in `~/.railsplan/ai.yml`:

```yaml
default:
  provider: openai
  model: gpt-4o
  api_key: <%= ENV['OPENAI_API_KEY'] %>
```

## Testing Strategy

### Running Tests
- `bin/rails test` - Run all tests
- `bin/rails test test/models/` - Run model tests
- `bin/rails test test/controllers/` - Run controller tests

### Test Structure
- Unit tests for models and services
- Integration tests for controllers
- System tests for user workflows

## Code Style and Conventions

- Follow Ruby community style guides
- Use RuboCop for code formatting
- Write descriptive commit messages
- Include tests for new features

## Common Development Tasks

### Adding a New Feature
1. Create a feature branch
2. Use `railsplan generate` for AI-assisted development
3. Write comprehensive tests
4. Update documentation
5. Submit a pull request

### Database Changes
1. Generate migration: `bin/rails generate migration`
2. Run migration: `bin/rails db:migrate`
3. Update schema documentation: `railsplan generate docs schema`

## Troubleshooting

### Common Issues
- **Bundle install fails**: Check Ruby version and dependencies
- **Database errors**: Ensure database is running and configured
- **Asset compilation fails**: Check Node.js version and npm packages

### Getting Help
- Check existing documentation
- Ask team members in Slack/Discord
- Review pull requests for similar features
- Use `railsplan doctor` for system diagnostics
