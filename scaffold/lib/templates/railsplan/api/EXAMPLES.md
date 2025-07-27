# API Module Example Responses

This document shows examples of the JSON:API compliant responses that the API module generates.

## GET /api/v1/workspaces

```json
{
  "data": [
    {
      "id": "1",
      "type": "workspace",
      "attributes": {
        "name": "Acme Corp",
        "slug": "acme-corp",
        "created_at": "2023-12-01T10:00:00Z",
        "updated_at": "2023-12-01T10:00:00Z"
      },
      "relationships": {
        "memberships": {
          "data": [
            { "id": "1", "type": "membership" },
            { "id": "2", "type": "membership" }
          ]
        }
      }
    }
  ],
  "included": [
    {
      "id": "1",
      "type": "membership",
      "attributes": {
        "role": "admin",
        "created_at": "2023-12-01T10:00:00Z",
        "updated_at": "2023-12-01T10:00:00Z"
      },
      "relationships": {
        "user": {
          "data": { "id": "1", "type": "user" }
        },
        "workspace": {
          "data": { "id": "1", "type": "workspace" }
        }
      }
    },
    {
      "id": "2",
      "type": "membership",
      "attributes": {
        "role": "member",
        "created_at": "2023-12-01T11:00:00Z",
        "updated_at": "2023-12-01T11:00:00Z"
      },
      "relationships": {
        "user": {
          "data": { "id": "2", "type": "user" }
        },
        "workspace": {
          "data": { "id": "1", "type": "workspace" }
        }
      }
    }
  ]
}
```

## POST /api/v1/workspaces

**Request:**
```json
{
  "data": {
    "type": "workspace",
    "attributes": {
      "name": "New Workspace",
      "slug": "new-workspace"
    }
  }
}
```

**Response (201 Created):**
```json
{
  "data": {
    "id": "2",
    "type": "workspace",
    "attributes": {
      "name": "New Workspace",
      "slug": "new-workspace",
      "created_at": "2023-12-01T12:00:00Z",
      "updated_at": "2023-12-01T12:00:00Z"
    },
    "relationships": {
      "memberships": {
        "data": [
          { "id": "3", "type": "membership" }
        ]
      }
    }
  }
}
```

## Error Responses

### Validation Error (422 Unprocessable Entity)
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
    },
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Slug can't be blank",
      "source": {
        "pointer": "/data/attributes/slug"
      }
    }
  ]
}
```

### Not Found (404)
```json
{
  "errors": [
    {
      "status": "404",
      "title": "Resource not found",
      "detail": "Couldn't find Workspace with 'id'=999"
    }
  ]
}
```

### Unauthorized (401)
```json
{
  "errors": [
    {
      "status": "401",
      "title": "Unauthorized",
      "detail": "You need to sign in or sign up before continuing."
    }
  ]
}
```

### Forbidden (403)
```json
{
  "errors": [
    {
      "status": "403",
      "title": "Access denied",
      "detail": "You are not authorized to perform this action."
    }
  ]
}
```

## OpenAPI Schema Preview

The generated OpenAPI schema includes:

- **Complete endpoint documentation** with request/response schemas
- **Authentication requirements** (Bearer token)
- **Error response schemas** for all HTTP status codes
- **Component schemas** for reusable data structures
- **Parameter definitions** for path, query, and body parameters

### Interactive Documentation

When you install the API module and run your Rails server, visit:
- `http://localhost:3000/api-docs` for the interactive Swagger UI

### Generated Schema Location

The schema is generated to:
- `swagger/v1/swagger.yaml` - OpenAPI 3.0 specification in YAML format

### CI Integration

The module includes rake tasks for CI:
```bash
# Generate the schema
rake api:generate_schema

# Validate that schema is up to date
rake api:validate_schema
```