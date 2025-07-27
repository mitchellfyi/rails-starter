# Development & Contribution Guide

This document spells out how to tackle tasks in the **RailsPlan** project. It isn't a legal contract – it's a practical set of guidelines that help you deliver high‑quality work and keep the project moving forward.

## 🎯 Project Overview

**RailsPlan** is a **hybrid project** that serves both as:
1. **Rails SaaS Starter Template** - A complete Rails application with marketing site
2. **RailsPlan Gem** - A global CLI tool for Rails SaaS bootstrapping

This dual nature requires careful consideration of both the Rails application and the Ruby gem components.

## 1. Planning Your Work

### 1.1 Understanding the Project Structure
```
railsplan/
├── app/                    # Rails application (marketing site, admin panel)
├── lib/railsplan/          # Ruby gem library
├── bin/railsplan           # CLI executable
├── scaffold/               # Template files for generated applications
├── docs/                   # Documentation
├── test/                   # Tests for both Rails app and gem
└── railsplan.gemspec       # Gem specification
```

### 1.2 Breaking Down Tasks
Decompose issues into smaller, manageable steps:
- **Rails App**: API design, database migrations, models, views, controllers, background jobs, tests
- **Gem**: CLI commands, module management, template generation, testing
- **Documentation**: README updates, module guides, API documentation
- **Testing**: Unit tests, integration tests, CLI tests, accessibility tests

### 1.3 Checking Existing Patterns
This project emphasizes consistency. Look at existing patterns:
- **Rails App**: Check `app/domains/` for domain-driven structure
- **Gem**: Check `lib/railsplan/` for CLI patterns
- **Modules**: Check `scaffold/lib/templates/railsplan/` for module conventions
- **Tests**: Check `test/` for testing patterns

## 2. Development Workflow

### 2.1 Setting Up Your Environment
```bash
# Clone and setup
git clone https://github.com/mitchellfyi/railsplan.git
cd railsplan

# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Build and install gem locally
gem build railsplan.gemspec
gem install ./railsplan-0.1.0.gem
```

### 2.2 Working on Different Components

#### **Rails Application (Marketing Site)**
```bash
# Start the development server
bin/rails server

# Run Rails tests
bin/rails test

# Check routes
bin/rails routes
```

#### **Ruby Gem (CLI)**
```bash
# Test CLI commands
bin/railsplan help
bin/railsplan list
bin/railsplan doctor

# Run gem tests
bin/rails test test/railsplan_cli_test.rb

# Build and test gem
gem build railsplan.gemspec
gem install ./railsplan-0.1.0.gem
```

#### **Template Files**
```bash
# Test template generation
bin/test-template

# Edit template files in scaffold/
# Test module installation
bin/railsplan add <module_name>
```

### 2.3 Testing Strategy
```bash
# Run all tests
bin/rails test

# Run specific test suites
bin/rails test test/railsplan_cli_test.rb
bin/rails test test/integration/
bin/rails test test/accessibility_test.rb

# Check code quality
bundle exec rubocop
```

## 3. Completing Tasks

### 3.1 Implementation Guidelines

#### **For Rails App Changes:**
1. **Follow Rails conventions** - Use latest Rails idioms and best practices
2. **Domain-driven design** - Organize code by business domains in `app/domains/`
3. **Test coverage** - Write comprehensive tests for new features
4. **Documentation** - Update relevant documentation and READMEs
5. **Accessibility** - Ensure all UI components are accessible
6. **Mobile responsiveness** - Test on different screen sizes

#### **For Gem Changes:**
1. **CLI design** - Follow Thor conventions and provide clear help text
2. **Error handling** - Graceful error handling with user-friendly messages
3. **Progress feedback** - Use TTY gems for interactive experiences
4. **Testing** - Comprehensive CLI testing with mocked inputs/outputs
5. **Documentation** - Update CLI help and documentation

#### **For Template Changes:**
1. **Modularity** - Each module should be self-contained
2. **Installation scripts** - Clear install/remove procedures
3. **Configuration** - Sensible defaults with easy customization
4. **Testing** - Test template generation and module installation
5. **Documentation** - Clear README for each module

### 3.2 Cross-Cutting Requirements
Always verify your feature addresses:

- **Security & Permissions** - Proper authentication and authorization
- **Audit Logging** - Track important actions for compliance
- **Documentation** - Clear, comprehensive documentation
- **Accessibility (A11y)** - WCAG compliance and screen reader support
- **SEO** - Proper meta tags and structured data
- **Internationalization (i18n)** - Multi-language support
- **Testing** - Unit, integration, and system tests
- **Health Checks & Debugging** - Monitoring and troubleshooting tools
- **UX & CX** - User and customer experience
- **Mobile Responsiveness** - Works on all device sizes
- **Performance** - Efficient queries and caching
- **Scalability** - Handles growth and load

### 3.3 Code Quality Standards
- **Ruby/Rails conventions** - Follow community best practices
- **Clean code** - Readable, maintainable, well-documented
- **Single responsibility** - Each class/method has one clear purpose
- **Error handling** - Graceful degradation and helpful error messages
- **Performance** - Avoid N+1 queries, use background jobs appropriately
- **Security** - Input validation, SQL injection prevention, XSS protection

## 4. Testing & Verification

### 4.1 Test Coverage
```bash
# Run full test suite
bin/rails test

# Run specific test categories
bin/rails test test/railsplan_cli_test.rb    # CLI tests
bin/rails test test/integration/              # Integration tests
bin/rails test test/accessibility_test.rb     # Accessibility tests
bin/rails test test/controllers/              # Controller tests
bin/rails test test/models/                   # Model tests
```

### 4.2 Code Quality Checks
```bash
# RuboCop for Ruby code style
bundle exec rubocop

# Check for security vulnerabilities
bundle audit

# Check gem build
gem build railsplan.gemspec
```

### 4.3 Manual Testing
```bash
# Test CLI functionality
bin/railsplan help
bin/railsplan list
bin/railsplan doctor

# Test marketing site
bin/rails server
# Visit http://localhost:3000

# Test template generation
bin/test-template
```

### 4.4 Integration Testing
```bash
# Test gem installation
gem install ./railsplan-0.1.0.gem
railsplan version

# Test template application
rails new testapp --dev -m scaffold/template.rb
cd testapp
bin/rails server
```

## 5. Documentation Standards

### 5.1 Code Documentation
- **Inline comments** - Explain complex logic and business rules
- **Method documentation** - Clear descriptions of parameters and return values
- **Class documentation** - Purpose and responsibilities of each class
- **Module documentation** - How modules work and integrate

### 5.2 User Documentation
- **README.md** - Clear getting started guide
- **Module guides** - Detailed documentation for each module
- **API documentation** - Comprehensive API reference
- **CLI help** - Clear command descriptions and examples

### 5.3 Developer Documentation
- **CONTRIBUTING.md** - How to contribute to the project
- **AGENTS.md** - This development process guide
- **Architecture docs** - System design and patterns
- **Testing guides** - How to write and run tests

## 6. Release Process

### 6.1 Pre-Release Checklist
- [ ] All tests pass
- [ ] Code quality checks pass
- [ ] Documentation is up to date
- [ ] Gem builds successfully
- [ ] Template generation works
- [ ] Marketing site functions correctly
- [ ] CLI commands work as expected
- [ ] No deprecation warnings
- [ ] Security audit completed
- [ ] Performance benchmarks met

### 6.2 Release Steps
1. **Update version** - Increment version in `lib/railsplan/version.rb`
2. **Update CHANGELOG** - Document all changes
3. **Build gem** - `gem build railsplan.gemspec`
4. **Test gem** - Install and test locally
5. **Push to GitHub** - Create release tag
6. **Publish to RubyGems** - `gem push railsplan-0.1.0.gem`

## 7. Common Tasks & Solutions

### 7.1 Adding a New Module
1. **Create module structure** in `scaffold/lib/templates/railsplan/`
2. **Write installation script** (`install.rb`)
3. **Write removal script** (`remove.rb`)
4. **Add documentation** (`README.md`)
5. **Add tests** in `test/`
6. **Update CLI** to recognize new module
7. **Update documentation** in `docs/modules/`

### 7.2 Adding a New CLI Command
1. **Add command** to `lib/railsplan/cli.rb`
2. **Write tests** in `test/railsplan_cli_test.rb`
3. **Update help text** and documentation
4. **Test command** manually
5. **Update README** with examples

### 7.3 Fixing Rails Edge Issues
1. **Identify the issue** - Check Rails edge compatibility
2. **Find workaround** - Use Rails-compatible alternatives
3. **Update dependencies** - Use compatible gem versions
4. **Add tests** - Ensure fix works correctly
5. **Document** - Note any limitations or workarounds

## 8. Quality Assurance

### 8.1 Code Review Checklist
- [ ] Follows project conventions
- [ ] Includes comprehensive tests
- [ ] Documentation is updated
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] Accessibility requirements met
- [ ] Mobile responsive
- [ ] Error handling is robust
- [ ] Logging is appropriate
- [ ] Internationalization ready

### 8.2 Performance Considerations
- **Database queries** - Avoid N+1 queries, use includes/joins
- **Background jobs** - Use Sidekiq for heavy operations
- **Caching** - Implement appropriate caching strategies
- **Asset optimization** - Minimize and compress assets
- **Database indexing** - Proper indexes for query performance

### 8.3 Security Considerations
- **Input validation** - Sanitize all user inputs
- **Authentication** - Secure user authentication
- **Authorization** - Proper access controls
- **Data protection** - Encrypt sensitive data
- **Audit logging** - Track important actions
- **Dependency security** - Regular security updates

## 9. Final Thoughts

Write robust, maintainable, well-documented, and tested code. You're building something lasting and useful that will be used by many developers. Make it easy for others to follow your work and contribute to the project.

**Remember**: This is a hybrid project that serves both as a Rails application and a Ruby gem. Always consider how changes affect both components and ensure they work together seamlessly.

---

*"The best way to predict the future is to invent it."* - Alan Kay
