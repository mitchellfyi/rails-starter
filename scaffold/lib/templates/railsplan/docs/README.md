# Docs Module

This module provides comprehensive documentation generation and management tools for your Rails SaaS application, including API documentation, setup guides, and module documentation.

## Features

- **Automated Documentation Generation**: Generate docs from code and modules
- **API Documentation**: OpenAPI specification generation
- **Module Documentation**: Aggregate documentation from all Synth modules  
- **Setup & Deployment Guides**: Comprehensive guides for getting started
- **Documentation Server**: Local server for browsing documentation
- **YARD Integration**: Code documentation from Ruby comments

## Installation

```bash
bin/railsplan add docs
```

This installs:
- YARD for code documentation
- Documentation generator service
- Rake tasks for doc generation
- HTML documentation portal
- Automated guide generation

## Usage

### Generate All Documentation
```bash
# Generate complete documentation suite
rails docs:generate

# Open documentation in browser
rails docs:serve
# Visit http://localhost:8080
```

### Generate Specific Documentation
```bash
# API documentation only
rails docs:api

# Module documentation only
rails docs:modules

# YARD code documentation
yard doc
```

## Documentation Types

### 1. Setup Guide (`docs/setup.md`)
Comprehensive setup instructions including:
- Prerequisites and installation
- Environment configuration
- Module installation with Synth CLI
- Testing and development workflow

### 2. Module Documentation (`docs/modules/`)
Auto-generated from each Synth module's README:
- Feature descriptions
- Installation instructions
- Usage examples
- Configuration options

### 3. API Documentation (`docs/api_specification.json`)
OpenAPI specification including:
- Endpoint definitions
- Request/response schemas
- Authentication requirements
- Example requests

### 4. Deployment Guide (`docs/deployment.md`)
Platform-specific deployment instructions for:
- Fly.io deployment
- Render deployment  
- Kamal (self-hosted) deployment
- Environment variable configuration

### 5. Code Documentation (`docs/api/`)
YARD-generated documentation from Ruby code comments:
- Class and module documentation
- Method signatures and examples
- Code organization and architecture

## Customization

### Adding Custom Documentation
```ruby
# app/services/documentation_generator.rb
class DocumentationGenerator
  def generate_custom_guide
    custom_content = <<~'MARKDOWN'
      # Custom Guide
      
      Your custom documentation content here.
    MARKDOWN
    
    File.write("#{output_dir}/custom.md", custom_content)
  end
end
```

### Customizing API Documentation
```ruby
def generate_api_paths
  # Introspect your controllers and routes
  api_paths = {}
  
  # Add custom endpoint documentation
  api_paths["/v1/custom"] = {
    "get" => {
      "summary" => "Custom endpoint",
      "responses" => {
        "200" => { "description" => "Success" }
      }
    }
  }
  
  api_paths
end
```

### Documentation Templates
Create custom templates in `docs/templates/`:

```erb
<!-- docs/templates/module.html.erb -->
<div class="module-doc">
  <h1><%= module_name %></h1>
  <p><%= description %></p>
  
  <h2>Installation</h2>
  <pre><code>bin/railsplan add <%= module_name %></code></pre>
</div>
```

## Automation

### CI/CD Integration
Add to your GitHub Actions workflow:

```yaml
# .github/workflows/docs.yml
name: Generate Documentation

on:
  push:
    branches: [ main ]

jobs:
  docs:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Generate documentation
        run: |
          bundle exec rails docs:generate
          bundle exec yard doc
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs
```

### Automated Updates
Set up automated documentation updates:

```ruby
# config/schedule.rb (using whenever gem)
every 1.day, at: '3:00 am' do
  rake "docs:generate"
end
```

## Configuration

### YARD Configuration (`.yardopts`)
```
--markup markdown
--output-dir docs/api
--readme README.md
--exclude spec/**/*
app/**/*.rb
lib/**/*.rb
```

### Documentation Structure
```
docs/
├── index.html              # Documentation portal
├── setup.md               # Setup guide  
├── deployment.md          # Deployment guide
├── CHANGELOG.md           # Project changelog
├── api_specification.json # OpenAPI spec
├── modules/               # Module documentation
│   ├── README.md          # Module index
│   ├── auth.md           # Auth module docs
│   └── billing.md        # Billing module docs
└── api/                  # YARD documentation
    └── index.html        # Code documentation
```

## Best Practices

### Writing Documentation
- Use clear, concise language
- Include code examples for all features
- Keep documentation up-to-date with code changes
- Use consistent formatting and structure

### Code Documentation
```ruby
# Use YARD tags for better documentation
class UserService
  # Creates a new user account with validation
  #
  # @param user_params [Hash] User attributes
  # @option user_params [String] :email User's email address
  # @option user_params [String] :name User's full name
  # @return [User] The created user object
  # @raise [ValidationError] When user data is invalid
  #
  # @example
  #   user = UserService.create_user(email: 'test@example.com', name: 'Test User')
  def self.create_user(user_params)
    # Implementation
  end
end
```

### Module Documentation
Each Synth module should include:
- Clear feature description
- Installation instructions
- Configuration examples
- Usage examples
- Troubleshooting guide

## Integration with Other Modules

The docs module automatically integrates with:
- **API Module**: Generates OpenAPI specifications
- **All Modules**: Aggregates README documentation
- **Testing Module**: Links to test documentation
- **Deploy Module**: Includes deployment guides

## Performance

- Documentation generation is optimized for large codebases
- Incremental updates for unchanged modules
- Caching for frequently accessed documentation
- Static file generation for fast serving

## Testing

```bash
bin/railsplan test docs
```

Test the documentation generator:
```ruby
RSpec.describe DocumentationGenerator do
  let(:generator) { DocumentationGenerator.new('tmp/test_docs') }
  
  it 'generates setup guide' do
    generator.generate_setup_guide
    expect(File.exist?('tmp/test_docs/setup.md')).to be true
  end
end
```

## Version

Current version: 1.0.0