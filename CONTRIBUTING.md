# Contributing to Rails SaaS Starter Template

Thank you for your interest in contributing! This project follows a **Fairware** model - it's free to use, but we welcome both financial and non-financial contributions.

## 🤝 How to Contribute

### 💰 Financial Support
If you find this project valuable, consider supporting development:
- **[Pay What You Want](https://mitchell.fyi)** - Direct contributions
- **[GitHub Sponsors](https://github.com/sponsors/mitchellfyi)** - Monthly support
- See [SUPPORT.md](docs/SUPPORT.md) for detailed information

### 🛠️ Code Contributions
Even without financial support, code contributions are welcome!

#### Getting Started
1. **Fork** the repository
2. **Clone** your fork locally
3. **Create** a feature branch: `git checkout -b feature/amazing-feature`
4. **Make** your changes
5. **Test** your changes thoroughly
6. **Commit** with clear messages
7. **Push** to your fork
8. **Open** a Pull Request

#### Development Setup
```bash
# Clone and setup
git clone https://github.com/mitchellfyi/railsplan.git
cd railsplan

# Install dependencies
bundle install

# Setup the database
bin/rails db:setup

# Run tests
bin/rails test
bin/railsplan test

# Check code quality
bundle exec rubocop
```

#### Running the Marketing Site Locally
This project includes a marketing website that showcases the Rails SaaS Starter Template. To run it locally:

```bash
# Start the Rails server
bin/rails server

# Visit the site at http://localhost:3000
```

**If port 3000 is in use, use a different port:**
```bash
# Use port 3001
bin/rails server -p 3001

# Or let Rails choose an available port
bin/rails server -p 0
```

**Marketing Site Features:**
- **Homepage** (`/`) - Overview and getting started
- **Documentation** (`/docs`) - Comprehensive guides and API docs
- **Modules** (`/docs/modules`) - Detailed module documentation
- **Admin Panel** (`/admin`) - Admin interface (if admin module is installed)

**Development Tips:**
- The site uses Tailwind CSS for styling
- Check `app/views/home/` for homepage content
- Check `app/views/docs/` for documentation pages
- Check `app/helpers/home_helper.rb` for dynamic content
- The site is fully responsive and accessible

**Testing the Marketing Site:**
```bash
# Run accessibility tests
bin/rails test test/accessibility_test.rb

# Run integration tests
bin/rails test test/integration/

# Check for broken links
bin/rails test test/controllers/
```

#### Gem Development
This project includes both a Rails application and a Ruby gem. To work on the gem:

```bash
# Build the gem
gem build railsplan.gemspec

# Install locally for testing
gem install ./railsplan-0.1.0.gem

# Test gem functionality
railsplan version
railsplan doctor

# Run gem tests
bundle exec rspec

# Uninstall local gem
gem uninstall railsplan
```

**Gem Structure:**
- `lib/railsplan/` - Core gem library
- `bin/railsplan` - CLI executable
- `templates/` - Gem templates
- `railsplan.gemspec` - Gem specification

#### Project Structure
This is a **hybrid project** that serves both as:
1. **Rails SaaS Starter Template** - A complete Rails application with marketing site
2. **RailsPlan Gem** - A global CLI tool for Rails SaaS bootstrapping

**Key Directories:**
- `app/` - Rails application (marketing site, admin panel)
- `lib/railsplan/` - Ruby gem library
- `scaffold/` - Template files for generated applications
- `docs/` - Documentation for the template
- `test/` - Tests for both Rails app and gem

**Development Workflow:**
- **Rails App**: Work on the marketing site, admin panel, and template features
- **Gem**: Work on the CLI commands and gem functionality
- **Template**: Work on the scaffold files that get copied to new applications

#### Common Development Tasks

**Working on the Marketing Site:**
```bash
# Start the development server
bin/rails server

# View the site at http://localhost:3000
# Edit files in app/views/, app/controllers/, app/helpers/
```

**Working on the CLI Gem:**
```bash
# Test CLI commands
bin/railsplan help
bin/railsplan list
bin/railsplan doctor

# Run CLI tests
bin/rails test test/railsplan_cli_test.rb

# Build and install gem for testing
gem build railsplan.gemspec
gem install ./railsplan-0.1.0.gem
```

**Working on Template Files:**
```bash
# Test template generation
bin/test-template

# Edit template files in scaffold/
# Test module installation
bin/railsplan add <module_name>
```

**Testing Everything:**
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

### 📝 Documentation
Help improve documentation:
- Fix typos and grammar
- Add missing examples
- Improve clarity
- Translate to other languages

### 🐛 Bug Reports
Report bugs with:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Ruby, Rails versions)
- Screenshots if applicable

### 💡 Feature Requests
Suggest new features:
- Clear description of the feature
- Use cases and benefits
- Implementation ideas (optional)
- Priority level

## 📋 Contribution Guidelines

### Code Style
- Follow Ruby/Rails conventions
- Use meaningful variable and method names
- Add comments for complex logic
- Keep methods focused and small

### Testing
- Write tests for new features
- Ensure all tests pass
- Add integration tests for modules
- Test edge cases

### Documentation
- Update README for user-facing changes
- Add inline documentation for complex code
- Update module documentation if needed
- Include examples in documentation

### Commit Messages
Use clear, descriptive commit messages:
```
feat: add new billing module
fix: resolve Time.current issue in CLI
docs: update README with Rails edge info
test: add tests for module installation
```

## 🎯 Areas That Need Help

### High Priority
- **Module testing** - Improve test coverage
- **Documentation** - More examples and guides
- **Performance** - Optimize module loading
- **Accessibility** - Improve a11y features
- **Gem functionality** - CLI improvements and new commands
- **Template system** - Better Rails template integration

### Medium Priority
- **New modules** - Additional integrations
- **Deployment** - More platform support
- **Internationalization** - Multi-language support
- **Analytics** - Usage tracking and insights

### Low Priority
- **UI improvements** - Better admin interface
- **CLI enhancements** - More railsplan commands
- **Examples** - Sample applications
- **Videos** - Tutorial content

## 🏆 Recognition

### Contributors
All contributors will be:
- Listed in the [Contributors](https://github.com/mitchellfyi/railsplan/graphs/contributors) section
- Mentioned in release notes
- Given credit in documentation

### Supporters
Financial supporters get:
- Priority issue responses
- Early access to features
- Recognition in release notes
- Direct communication channel

## 📞 Getting Help

### Questions?
- **Issues**: Use GitHub Issues for bugs and feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Email**: [mitchell@mitchell.fyi](mailto:mitchell@mitchell.fyi)

### Code Reviews
- All PRs are reviewed by maintainers
- We aim for 48-hour response time
- Constructive feedback is provided
- We help contributors improve their code

## 🙏 Thank You

Every contribution, whether code, documentation, or financial support, helps make this project better for everyone. Thank you for being part of the community!

---

*"The best way to predict the future is to invent it."* - Alan Kay 