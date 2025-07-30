# API Documentation

This document describes the REST API endpoints available in the application.

## Base URL

```
Development: http://localhost:3000
Production: https://your-domain.com
```

## Authentication

Most API endpoints require authentication. Include the following header:

```
Authorization: Bearer <your-token>
```

## Endpoints

No API routes found.


## Response Format

All API responses follow this structure:

```json
{
  "data": {},
  "meta": {
    "status": "success",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

## Error Handling

Error responses include:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message"
  },
  "meta": {
    "status": "error",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```
