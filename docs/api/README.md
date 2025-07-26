# API Documentation

The Rails SaaS Starter Template provides RESTful JSON:API compliant endpoints for all major functionality.

## Overview

- **Base URL**: `https://yourapp.com/api/v1`
- **Format**: JSON:API specification
- **Authentication**: Bearer token or session-based
- **Versioning**: URL path versioning (`/api/v1/`)

## Authentication

### Bearer Token Authentication
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" https://yourapp.com/api/v1/workspaces
```

### Session Authentication
```bash
# Login first
curl -X POST https://yourapp.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# Use session cookie for subsequent requests
curl -b cookies.txt https://yourapp.com/api/v1/workspaces
```

## Core Resources

### Workspaces

**List Workspaces**
```http
GET /api/v1/workspaces
```

**Get Workspace**
```http
GET /api/v1/workspaces/:id
```

**Create Workspace**
```http
POST /api/v1/workspaces
Content-Type: application/json

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

### Users & Authentication

**Register User**
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "data": {
    "type": "user",
    "attributes": {
      "email": "user@example.com",
      "password": "password123",
      "password_confirmation": "password123"
    }
  }
}
```

**Login**
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

## Module-Specific APIs

### AI Module

**List Prompt Templates**
```http
GET /api/v1/prompt_templates
```

**Create LLM Job**
```http
POST /api/v1/llm_jobs
Content-Type: application/json

{
  "data": {
    "type": "llm_job",
    "attributes": {
      "template_id": 1,
      "model": "gpt-4",
      "context": {
        "subject": "Product Launch",
        "tone": "professional"
      }
    }
  }
}
```

### Billing Module

**List Subscriptions**
```http
GET /api/v1/subscriptions
```

**Create Subscription**
```http
POST /api/v1/subscriptions
Content-Type: application/json

{
  "data": {
    "type": "subscription",
    "attributes": {
      "plan_id": "pro_monthly",
      "payment_method": "pm_1234567890"
    }
  }
}
```

## Error Handling

All endpoints return consistent error responses following JSON:API format:

```json
{
  "errors": [
    {
      "id": "unique_error_id",
      "status": "422",
      "code": "validation_failed",
      "title": "Validation Failed",
      "detail": "Name can't be blank",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

### Common Error Codes

- `400` - Bad Request: Invalid JSON or missing required fields
- `401` - Unauthorized: Missing or invalid authentication
- `403` - Forbidden: Insufficient permissions
- `404` - Not Found: Resource does not exist
- `422` - Unprocessable Entity: Validation errors
- `429` - Too Many Requests: Rate limit exceeded
- `500` - Internal Server Error: Server error

## Rate Limiting

API endpoints are rate limited:

- **Authenticated users**: 1000 requests per hour
- **Unauthenticated**: 100 requests per hour

Rate limit headers are included in responses:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Pagination

Large collections are paginated using cursor-based pagination:

```http
GET /api/v1/workspaces?page[size]=20&page[after]=eyJpZCI6MTAwfQ==
```

Response includes pagination metadata:
```json
{
  "data": [...],
  "meta": {
    "pagination": {
      "current_page": 2,
      "per_page": 20,
      "total_pages": 5,
      "total_count": 100
    }
  },
  "links": {
    "first": "/api/v1/workspaces?page[size]=20",
    "prev": "/api/v1/workspaces?page[size]=20&page[before]=...",
    "next": "/api/v1/workspaces?page[size]=20&page[after]=...",
    "last": "/api/v1/workspaces?page[size]=20&page[after]=..."
  }
}
```

## Filtering & Sorting

**Filtering:**
```http
GET /api/v1/workspaces?filter[active]=true&filter[name]=contains:acme
```

**Sorting:**
```http
GET /api/v1/workspaces?sort=-created_at,name
```

**Including Related Resources:**
```http
GET /api/v1/workspaces?include=memberships,memberships.user
```

## OpenAPI Schema

The complete API schema is available as OpenAPI 3.0 specification:

- **Development**: `http://localhost:3000/api-docs`
- **Interactive Docs**: `http://localhost:3000/api-docs/ui`
- **Schema Download**: `http://localhost:3000/api-docs.json`

### Generating Documentation

Update the OpenAPI schema when adding new endpoints:

```bash
# Generate/update schema
bin/rails rswag:specs:swaggerize

# Serve interactive documentation
bin/rails server
# Visit http://localhost:3000/api-docs/ui
```

## SDKs & Libraries

### JavaScript/TypeScript
```bash
npm install @yourapp/api-client
```

```javascript
import { ApiClient } from '@yourapp/api-client';

const client = new ApiClient({
  baseURL: 'https://yourapp.com/api/v1',
  token: 'your_auth_token'
});

const workspaces = await client.workspaces.list();
```

### Ruby
```ruby
# Gemfile
gem 'yourapp-api-client'

# Usage
client = YourApp::ApiClient.new(
  base_url: 'https://yourapp.com/api/v1',
  token: 'your_auth_token'
)

workspaces = client.workspaces.list
```

### Python
```bash
pip install yourapp-api-client
```

```python
from yourapp import ApiClient

client = ApiClient(
    base_url='https://yourapp.com/api/v1',
    token='your_auth_token'
)

workspaces = client.workspaces.list()
```

## Webhooks

Some modules provide webhook endpoints for real-time notifications:

### Billing Webhooks
```http
POST /api/v1/webhooks/stripe
Content-Type: application/json
Stripe-Signature: t=1640995200,v1=...

{
  "id": "evt_1234567890",
  "object": "event",
  "type": "invoice.payment_succeeded",
  "data": {
    "object": {
      "id": "in_1234567890",
      "amount_paid": 2000,
      "customer": "cus_1234567890"
    }
  }
}
```

### Webhook Security

All webhooks are secured with signature verification:

```ruby
# Verify Stripe webhooks
def verify_stripe_signature
  payload = request.body.read
  sig_header = request.env['HTTP_STRIPE_SIGNATURE']
  
  begin
    Stripe::Webhook.construct_event(
      payload, sig_header, Rails.application.credentials.stripe.webhook_secret
    )
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end
end
```

## Development Tools

### API Testing
```bash
# Test with curl
curl -X GET https://yourapp.com/api/v1/workspaces \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/vnd.api+json"

# Test with HTTPie
http GET https://yourapp.com/api/v1/workspaces \
  Authorization:"Bearer YOUR_TOKEN" \
  Accept:"application/vnd.api+json"
```

### Postman Collection
Import the Postman collection for easy testing:
- Download: `https://yourapp.com/api-docs/postman.json`
- Variables: Set `{{base_url}}` and `{{auth_token}}`

### Insomnia Workspace
Import the Insomnia workspace:
- Download: `https://yourapp.com/api-docs/insomnia.json`

## Versioning Strategy

### URL Versioning
All endpoints include version in the URL path:
- Current: `/api/v1/`
- Future: `/api/v2/`

### Backward Compatibility
- Minor version changes are backward compatible
- Deprecated fields include `deprecated: true` in schema
- Breaking changes require new major version

### Migration Guides
When upgrading API versions:
1. Review the [CHANGELOG.md](../CHANGELOG.md)
2. Check deprecation warnings in responses
3. Update client code gradually
4. Test thoroughly before switching versions

For detailed endpoint documentation, visit the interactive API docs at `/api-docs/ui` in your application.