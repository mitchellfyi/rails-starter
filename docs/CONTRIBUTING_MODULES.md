# Contributing New Modules

This guide explains how to create new feature modules for the Rails SaaS Starter Template using the Synth CLI system.

## Module Structure

Every module follows a consistent structure under `lib/templates/synth/`:

```
lib/templates/synth/your_module/
├── install.rb          # Installation script
├── remove.rb           # Removal script (optional)
├── README.md           # Module documentation
├── migrations/         # Database migrations
├── app/               # Application code
│   ├── models/
│   ├── controllers/
│   ├── services/
│   ├── jobs/
│   └── views/
├── config/            # Configuration files
│   ├── routes.rb
│   └── initializers/
├── spec/              # RSpec tests
├── test/              # Minitest tests
└── lib/               # Module-specific libraries
```

## Creating a New Module

### 1. Generate Module Structure

```bash
# Create basic structure
mkdir -p lib/templates/synth/your_module/{app/{models,controllers,services,jobs,views},config/{initializers},migrations,spec,test,lib}

# Create core files
touch lib/templates/synth/your_module/{install.rb,remove.rb,README.md}
```

### 2. Write the Installation Script

The `install.rb` file is executed when users run `bin/synth add your_module`:

```ruby
# lib/templates/synth/your_module/install.rb
# frozen_string_literal: true

say_status :synth_your_module, "Installing Your Module"

# Add gems to Gemfile
gem 'your_required_gem', '~> 1.0'
gem 'another_gem', '~> 2.0'

# Add gems for specific environments
gem_group :development, :test do
  gem 'your_test_gem', '~> 1.0'
end

# Copy application files
directory "app", "app", force: true

# Copy configuration files
copy_file "config/initializers/your_module.rb", "config/initializers/your_module.rb"

# Copy migrations
copy_file "migrations/001_create_your_models.rb", 
          "db/migrate/#{Time.current.strftime('%Y%m%d%H%M%S')}_create_your_models.rb"

# Add routes
route <<~RUBY
  # Your Module routes
  namespace :api do
    namespace :v1 do
      resources :your_resources
    end
  end
RUBY

# Post-installation tasks
after_bundle do
  # Run migrations
  rails_command "db:migrate"
  
  # Generate additional files
  generate "your_module:install"
  
  # Seed initial data
  append_to_file "db/seeds.rb", <<~RUBY
    
    # Your Module seeds
    if defined?(YourModel)
      YourModel.find_or_create_by(name: "Default") do |model|
        model.description = "Default model created by installer"
      end
    end
  RUBY
  
  say_status :synth_your_module, "Your Module installed successfully!"
  say_status :next_steps, "Configure your module settings in config/initializers/your_module.rb"
end
```

### 3. Write Module Documentation

Create comprehensive documentation in `README.md`:

```markdown
# Your Module

Brief description of what this module provides and why it's useful.

## Features

- Feature 1: Description
- Feature 2: Description  
- Feature 3: Description

## Installation

```bash
bin/synth add your_module
```

## Configuration

After installation, configure the module:

```ruby
# config/initializers/your_module.rb
Rails.application.config.your_module = ActiveSupport::OrderedOptions.new
Rails.application.config.your_module.setting = "value"
```

## Usage

### Basic Usage
Code examples showing how to use the module

### Advanced Usage
More complex examples and customization options

## API Endpoints

Document any API endpoints provided:

- `GET /api/v1/your_resources` - List resources
- `POST /api/v1/your_resources` - Create resource

## Testing

```bash
bin/synth test your_module
```

## Customization

How to customize and extend the module

## Troubleshooting

Common issues and solutions

## Removal

```bash
bin/synth remove your_module
```
```

### 4. Implement Application Code

Follow Rails conventions and existing patterns:

```ruby
# app/models/your_model.rb
class YourModel < ApplicationRecord
  include Auditable  # Use existing concerns
  
  belongs_to :workspace
  has_many :your_relations, dependent: :destroy
  
  validates :name, presence: true, uniqueness: { scope: :workspace_id }
  
  scope :active, -> { where(active: true) }
end
```

```ruby
# app/controllers/api/v1/your_resources_controller.rb
class Api::V1::YourResourcesController < Api::V1::BaseController
  include Paginatable
  include Filterable
  
  before_action :authenticate_user!
  before_action :set_resource, only: [:show, :update, :destroy]
  
  def index
    @resources = current_workspace.your_resources
                                  .includes(:your_relations)
                                  .page(params[:page])
    
    render json: serialize_collection(@resources)
  end
  
  private
  
  def set_resource
    @resource = current_workspace.your_resources.find(params[:id])
  end
  
  def resource_params
    params.require(:your_resource).permit(:name, :description, :active)
  end
end
```

### 5. Add Comprehensive Tests

Write tests for all functionality:

```ruby
# spec/models/your_model_spec.rb
require 'rails_helper'

RSpec.describe YourModel, type: :model do
  let(:workspace) { create(:workspace) }
  let(:your_model) { build(:your_model, workspace: workspace) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).scoped_to(:workspace_id) }
  end

  describe 'associations' do
    it { should belong_to(:workspace) }
    it { should have_many(:your_relations).dependent(:destroy) }
  end

  describe 'scopes' do
    it 'returns active records' do
      active = create(:your_model, workspace: workspace, active: true)
      inactive = create(:your_model, workspace: workspace, active: false)
      
      expect(YourModel.active).to include(active)
      expect(YourModel.active).not_to include(inactive)
    end
  end
end
```

```ruby
# spec/requests/api/v1/your_resources_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::YourResources', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace) }
  
  before { sign_in(user) }
  
  describe 'GET /api/v1/your_resources' do
    let!(:resources) { create_list(:your_resource, 3, workspace: workspace) }
    
    it 'returns all workspace resources' do
      get '/api/v1/your_resources'
      
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(3)
    end
  end
  
  describe 'POST /api/v1/your_resources' do
    let(:valid_params) do
      {
        your_resource: {
          name: 'Test Resource',
          description: 'Test description'
        }
      }
    end
    
    it 'creates a new resource' do
      expect {
        post '/api/v1/your_resources', params: valid_params
      }.to change(YourResource, :count).by(1)
      
      expect(response).to have_http_status(:created)
    end
  end
end
```

### 6. Add Database Migrations

Create migrations following Rails conventions:

```ruby
# migrations/001_create_your_models.rb
class CreateYourModels < ActiveRecord::Migration[7.1]
  def change
    create_table :your_models do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true
      t.references :workspace, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :your_models, [:workspace_id, :name], unique: true
  end
end
```

### 7. Configure Routes

```ruby
# config/routes.rb
# Your Module routes
namespace :api do
  namespace :v1 do
    resources :your_resources, except: [:new, :edit] do
      member do
        patch :activate
        patch :deactivate
      end
    end
  end
end

# Admin routes (if applicable)
namespace :admin do
  resources :your_resources, only: [:index, :show]
end
```

### 8. Create Removal Script (Optional)

```ruby
# remove.rb
# frozen_string_literal: true

say_status :synth_your_module, "Removing Your Module"

# Warning about data loss
if yes?("This will remove all Your Module data. Continue? (y/N)")
  
  # Remove routes
  gsub_file "config/routes.rb", /^\s*# Your Module routes.*?^  end$/m, ""
  
  # Remove migrations (optional - usually keep for data safety)
  # remove_file Dir.glob("db/migrate/*_create_your_models.rb").first
  
  # Remove application files
  remove_dir "app/models/your_model.rb"
  remove_dir "app/controllers/api/v1/your_resources_controller.rb"
  
  # Remove initializer
  remove_file "config/initializers/your_module.rb"
  
  # Remove from Gemfile
  gsub_file "Gemfile", /^gem 'your_required_gem'.*\n/, ""
  
  say_status :synth_your_module, "Your Module removed successfully!"
  say_status :warning, "Database tables and data preserved for safety"
  
else
  say_status :cancelled, "Your Module removal cancelled"
end
```

## Module Standards

### Code Quality
- Follow Rails conventions and existing patterns
- Use existing concerns and base classes where possible
- Maintain consistent naming across all modules
- Include comprehensive documentation

### Testing Requirements
- Minimum 90% test coverage
- Unit tests for all models and services
- Integration tests for all controllers
- System tests for critical user flows
- Mock all external services

### Documentation Standards
- Complete README with installation, usage, and API documentation
- Inline code comments for complex logic
- Update main README if module adds core functionality
- Include troubleshooting section

### Dependencies
- Use established gems when possible
- Minimize new dependencies
- Specify version constraints
- Document any system requirements

## Integration with Synth CLI

### Registering Your Module

The CLI automatically discovers modules in `lib/templates/synth/`. No registration required.

### CLI Command Integration

Your module can extend the CLI with custom commands:

```ruby
# lib/synth/commands/your_module.rb
module Synth
  module Commands
    class YourModule < Thor
      desc 'configure', 'Configure Your Module settings'
      def configure
        # Configuration logic
      end
      
      desc 'status', 'Show Your Module status'
      def status
        # Status logic
      end
    end
  end
end
```

Register in the main CLI:

```ruby
# lib/synth/cli.rb
require_relative 'commands/your_module'

class CLI < Thor
  register(Synth::Commands::YourModule, 'your_module', 'your_module COMMAND', 'Your Module commands')
end
```

## Testing Your Module

### Local Testing
```bash
# Test installation
bin/synth add your_module

# Test functionality
bin/synth test your_module

# Test removal
bin/synth remove your_module
```

### Integration Testing
```bash
# Test with fresh Rails app
rails new test_app --dev -m template.rb
cd test_app
bin/synth add your_module
bin/rails test
```

## Publishing Guidelines

### Version Management
- Follow semantic versioning
- Tag releases in Git
- Update CHANGELOG.md
- Document breaking changes

### Quality Checklist
Before submitting your module:

- [ ] Installation script works correctly
- [ ] All tests pass
- [ ] Documentation is complete
- [ ] Follows established patterns
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] Removal script works (if provided)

### Contribution Process
1. Fork the repository
2. Create a feature branch
3. Implement your module
4. Add comprehensive tests
5. Update documentation
6. Submit a pull request

## Example Modules

Study existing modules for patterns:

- **AI Module**: Complex service integration with jobs
- **Billing Module**: External API integration with webhooks  
- **CMS Module**: Content management with rich text
- **Admin Module**: UI components and authorization

## Getting Help

- Review existing modules for patterns
- Check the main [AGENTS.md](../AGENTS.md) for general guidelines
- Open an issue for questions or support
- Join community discussions for feedback