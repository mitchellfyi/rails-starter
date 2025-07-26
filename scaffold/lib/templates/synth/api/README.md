# API Module

Provides JSON:API compliant endpoints and automatic OpenAPI schema generation for Rails SaaS Starter applications.

## Features

- **JSON:API Compliance**: All API endpoints follow the [JSON:API specification](https://jsonapi.org/)
- **OpenAPI Documentation**: Automatic generation of OpenAPI 3.0 schemas using [rswag](https://github.com/rswag/rswag)
- **Base API Controllers**: Pre-configured controllers with error handling and authentication
- **Serializers**: JSON:API serializers using [jsonapi-serializer](https://github.com/jsonapi-serializer/jsonapi-serializer)
- **CI Integration**: Automatic schema validation in continuous integration
- **Comprehensive Testing**: Full test suite with request specs that generate documentation

## Installation

Install this module via:

```sh
bin/synth add api
```

This will add the necessary controllers, serializers, specs, policies, routes, and configuration files.

## Architecture

### Base Controller

The `Api::BaseController` provides:
- JSON:API response helpers
- Authentication enforcement
- Error handling with proper JSON:API error responses
- Content type enforcement

### Response Helpers

- `render_jsonapi_resource(resource, serializer_class, options)` - Render single resources
- `render_jsonapi_collection(resources, serializer_class, options)` - Render collections
- `render_jsonapi_error(status:, title:, detail:)` - Render single errors
- `render_jsonapi_errors(errors, status:)` - Render multiple errors

### Serializers

All serializers inherit from `ApplicationSerializer` which includes `JSONAPI::Serializer` with common configuration:
- Underscore key transformation
- Relationship handling
- Meta data support

### Error Handling

Automatic error handling for:
- `ActiveRecord::RecordNotFound` → 404 Not Found
- `ActiveRecord::RecordInvalid` → 422 Unprocessable Entity
- `Pundit::NotAuthorizedError` → 403 Forbidden

## Usage

### Creating API Controllers

```ruby
module Api
  module V1
    class PostsController < Api::BaseController
      def index
        posts = policy_scope(Post)
        render_jsonapi_collection(posts, PostSerializer)
      end

      def show
        post = Post.find(params[:id])
        authorize post
        render_jsonapi_resource(post, PostSerializer)
      end

      def create
        post = Post.new(post_params)
        authorize post

        if post.save
          render_jsonapi_resource(post, PostSerializer, status: :created)
        else
          render_jsonapi_errors(post.errors.full_messages)
        end
      end

      private

      def post_params
        params.require(:data).require(:attributes).permit(:title, :content)
      end
    end
  end
end
```

### Creating Serializers

```ruby
class PostSerializer < ApplicationSerializer
  attributes :title, :content, :published_at

  belongs_to :author, serializer: UserSerializer
  has_many :comments, serializer: CommentSerializer
end
```

### API Documentation

API endpoints are documented using rswag specs in `spec/requests/api/`:

```ruby
require 'swagger_helper'

RSpec.describe 'api/v1/posts', type: :request do
  path '/api/v1/posts' do
    get('list posts') do
      tags 'Posts'
      produces 'application/json'
      
      response(200, 'successful') do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Post' }
                 }
               }
        
        run_test!
      end
    end
  end
end
```

## OpenAPI Schema Generation

### Generate Documentation

```sh
# Generate OpenAPI schema from specs
rake api:generate_schema

# Validate schema is up to date (useful for CI)
rake api:validate_schema
```

### Access Documentation

Visit the interactive API documentation at:
- Development: `http://localhost:3000/api-docs`
- Production: `https://yourdomain.com/api-docs`

## JSON:API Compliance

### Request Format

```json
{
  "data": {
    "type": "workspace",
    "attributes": {
      "name": "My Workspace",
      "slug": "my-workspace"
    }
  }
}
```

### Response Format

```json
{
  "data": {
    "id": "1",
    "type": "workspace",
    "attributes": {
      "name": "My Workspace",
      "slug": "my-workspace",
      "created_at": "2023-01-01T00:00:00Z",
      "updated_at": "2023-01-01T00:00:00Z"
    },
    "relationships": {
      "memberships": {
        "data": [
          { "id": "1", "type": "membership" }
        ]
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "membership",
      "attributes": {
        "role": "admin"
      }
    }
  ]
}
```

### Error Format

```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Name can't be blank",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

## Continuous Integration

Add to your CI workflow to ensure schema stays updated:

```yaml
# .github/workflows/test.yml
- name: Validate API Schema
  run: bundle exec rake api:validate_schema
```

## Testing

The module includes comprehensive test coverage:

```sh
# Run all API tests
bundle exec rspec spec/requests/api/

# Run specific endpoint tests
bundle exec rspec spec/requests/api/v1/workspaces_spec.rb

# Generate and test documentation
bundle exec rake api:generate_schema
```

## Configuration

### Security

API endpoints require authentication by default. Override in specific controllers if needed:

```ruby
class PublicController < Api::BaseController
  skip_before_action :authenticate_user!
end
```

### Serializer Configuration

Customize global serializer behavior in `app/serializers/application_serializer.rb`:

```ruby
class ApplicationSerializer
  include JSONAPI::Serializer
  
  # Global configuration
  set_key_transform :camel_lower  # Use camelCase keys
  set_id :uuid                    # Use UUID as ID
end
```

### OpenAPI Configuration

Customize OpenAPI settings in `spec/swagger_helper.rb`:

```ruby
config.swagger_docs = {
  'v1/swagger.yaml' => {
    openapi: '3.0.1',
    info: {
      title: 'Your API',
      version: 'v1',
      description: 'Your API description'
    }
  }
}
```