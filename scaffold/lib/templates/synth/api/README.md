# API Module

This module provides JSON:API compliant REST endpoints with OpenAPI documentation, versioning, and authentication via API tokens.

## Features

- **JSON:API Compliance**: Standardized API responses with proper serialization
- **API Versioning**: Header-based versioning with backward compatibility
- **OpenAPI Documentation**: Automatic documentation generation with Swagger UI
- **Authentication**: Token-based authentication with API keys
- **CORS Support**: Configurable cross-origin resource sharing
- **Error Handling**: Standardized error responses

## Installation

```bash
bin/synth add api
```

This installs:
- JSON:API serialization with jsonapi-serializer
- API versioning with versionist
- OpenAPI documentation with rswag
- CORS configuration
- Token-based authentication system

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Add API routes:**
   ```ruby
   # config/routes.rb
   namespace :api do
     api_version(module: 'V1', header: { name: 'X-API-Version', value: 'v1' }) do
       resources :users
       resources :posts, only: [:index, :show]
     end
   end

   # Mount Swagger UI
   mount Rswag::Ui::Engine => '/api-docs'
   mount Rswag::Api::Engine => '/api-docs'
   ```

3. **Configure CORS for production:**
   ```ruby
   # config/initializers/cors.rb
   # Update origins to match your domain
   origins ['https://yourdomain.com']
   ```

4. **Generate API documentation:**
   ```bash
   bundle exec rswag:specs:swaggerize
   ```

## Usage

### API Token Authentication

Generate API tokens for users:

```ruby
# Create API token
token = ApiToken.create!(
  user: current_user,
  name: "Mobile App",
  token: SecureRandom.hex(32),
  active: true
)

# Use in API requests
headers = { 'Authorization' => "Bearer #{token.token}" }
```

### Making API Requests

```bash
# Get users with pagination
curl -H "Authorization: Bearer your_token" \
     -H "X-API-Version: v1" \
     "https://yourapp.com/api/v1/users?page=1&per_page=10"

# Create a user
curl -X POST \
     -H "Authorization: Bearer your_token" \
     -H "X-API-Version: v1" \
     -H "Content-Type: application/json" \
     -d '{"user": {"email": "test@example.com", "first_name": "Test"}}' \
     "https://yourapp.com/api/v1/users"
```

### Creating Serializers

```ruby
class PostSerializer
  include JSONAPI::Serializer
  
  attributes :title, :content, :published_at
  
  belongs_to :author, serializer: UserSerializer
  has_many :comments, serializer: CommentSerializer
  
  attribute :excerpt do |post|
    post.content.truncate(200)
  end
end
```

### API Controllers

```ruby
class Api::V1::PostsController < Api::BaseController
  api :v1
  
  def index
    posts = Post.published.page(params[:page])
    authorize posts
    
    render json: PostSerializer.new(
      posts, 
      include: [:author],
      meta: pagination_meta(posts)
    )
  end
end
```

### Error Handling

The module provides standardized error responses:

```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Email can't be blank",
      "source": { "pointer": "/data/attributes/email" }
    }
  ]
}
```

## API Documentation

Access interactive API documentation at `/api-docs` after running:

```bash
bundle exec rswag:specs:swaggerize
```

### Writing API Tests

```ruby
# spec/requests/api/v1/posts_spec.rb
require 'swagger_helper'

RSpec.describe 'api/v1/posts' do
  path '/api/v1/posts' do
    get('list posts') do
      tags 'Posts'
      produces 'application/json'
      
      response(200, 'successful') do
        schema type: :object,
          properties: {
            data: { type: :array, items: { '$ref' => '#/components/schemas/post' } }
          }
        
        run_test!
      end
    end
  end
end
```

## Versioning

API versions are managed via headers:

```ruby
# V2 controller
class Api::V2::UsersController < Api::BaseController
  api :v2
  
  # V2-specific logic
end
```

Clients specify version with:
```
X-API-Version: v2
```

## Security

- Token-based authentication
- Rate limiting (implement with rack-attack)
- CORS configuration
- Input validation and sanitization
- Authorization with Pundit

## Testing

```bash
bin/synth test api
```

## Performance

- Pagination for large datasets
- JSON response caching
- Database query optimization
- API rate limiting

## Version

Current version: 1.0.0