# SentinelFlow API Documentation

## Overview

SentinelFlow provides a RESTful API for monitoring incidents, integrations, and system health. All API endpoints are prefixed with `/api/` and return JSON responses.

## Base URL

```
Local Development: http://localhost:3000/api
Production: https://your-domain.com/api
```

## Authentication

Most endpoints require authentication via session cookies. Authentication is handled through Salesforce OAuth2 flow.

### Authentication Flow

1. Initiate OAuth at `/auth/salesforce`
2. User authenticates with Salesforce
3. Callback to `/auth/callback` with authorization code
4. Session is established
5. Subsequent API calls use the session cookie

## Response Format

All API responses follow this structure:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

Error responses:

```json
{
  "success": false,
  "data": null,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "details": { ... }
  },
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Endpoints

### Health & System

#### GET /health

Health check endpoint. No authentication required.

**Response:**
```json
{
  "status": "ok",
  "platform": "SentinelFlow",
  "phase": "phase-1-foundation",
  "readiness": {
    "phase": "phase-1-foundation",
    "ready": true,
    "missingEnv": [],
    "workstreams": {
      "appConfig": true,
      "infrastructureScaffold": true,
      "dataModelBaseline": true,
      "operationalEndpoints": true
    }
  },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 3600.123
}
```

#### GET /api/system/context

Returns system configuration and context. Authentication required.

**Response:**
```json
{
  "platform": {
    "name": "Salesforce Enterprise Operations Monitoring Platform",
    "shortName": "SentinelFlow",
    "version": "1.0.0",
    "phase": "phase-1-foundation"
  },
  "environment": {
    "nodeEnv": "development",
    "appEnv": "local",
    "salesforceOrg": "sentinelFlow-dev-edition",
    "timezone": "UTC"
  },
  "services": {
    "salesforce": {
      "instanceUrl": "https://login.salesforce.com",
      "streamingMode": "platform-events"
    },
    "middleware": {
      "port": 3000
    },
    "queue": {
      "provider": "redis",
      "topic": "sentinelFlow.platform-events"
    },
    "database": {
      "provider": "postgresql",
      "urlConfigured": true
    },
    "notifications": {
      "slackWebhookConfigured": false,
      "emailAlertsEnabled": false
    }
  },
  "salesforce": {
    "customObjects": [
      "Incident__c",
      "Integration_Log__c",
      "SLA_Policy__c",
      "Environment__c",
      "Deployment_Record__c",
      "Audit_Trail__c"
    ]
  },
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### GET /api/system/readiness

Returns system readiness status. Authentication required.

**Response:**
```json
{
  "status": "ok",
  "readiness": {
    "phase": "phase-1-foundation",
    "ready": true,
    "missingEnv": [],
    "workstreams": {
      "appConfig": true,
      "infrastructureScaffold": true,
      "dataModelBaseline": true,
      "operationalEndpoints": true
    }
  },
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Incidents

#### GET /api/records/incidents

Retrieve incidents with optional filtering.

**Query Parameters:**
- `status` (optional): Filter by status (Open, Investigating, Healing, Resolved)
- `severity` (optional): Filter by severity (Critical, High, Medium, Low)
- `limit` (optional): Maximum number of results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "incidents": [
      {
        "id": "INC-0041",
        "description": "API Gateway timeout — Payment Service",
        "severity": "Critical",
        "status": "Open",
        "integration": "Payment API",
        "environment": "Production",
        "usersAffected": 1240,
        "slaStatus": "Breached",
        "createdAt": "2024-01-01T00:00:00.000Z",
        "rootCause": "Connection pool exhausted due to spike in transaction volume",
        "recommendedAction": "Restart Service",
        "confidence": 92,
        "impact": "High"
      }
    ],
    "total": 1,
    "limit": 50,
    "offset": 0
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### GET /api/records/incidents/:id

Retrieve a specific incident by ID.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "INC-0041",
    "description": "API Gateway timeout — Payment Service",
    "severity": "Critical",
    "status": "Open",
    "integration": "Payment API",
    "environment": "Production",
    "usersAffected": 1240,
    "slaStatus": "Breached",
    "createdAt": "2024-01-01T00:00:00.000Z",
    "resolvedAt": null,
    "rootCause": "Connection pool exhausted due to spike in transaction volume",
    "recommendedAction": "Restart Service",
    "confidence": 92,
    "impact": "High",
    "slaPolicy": {
      "id": "SLA-001",
      "responseTimeMin": 5,
      "resolutionTimeMin": 30
    },
    "integrationLog": {
      "id": "LOG-001",
      "apiName": "Payment API",
      "status": "Failed",
      "responseTime": 8420,
      "errorMessage": "Connection pool exhausted"
    },
    "activityTimeline": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "action": "Created",
        "user": "System",
        "details": "Incident created from Integration_Log__c"
      }
    ]
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### POST /api/records/incidents/:id/analyze

Trigger AI analysis for an incident.

**Response:**
```json
{
  "success": true,
  "data": {
    "incidentId": "INC-0041",
    "status": "Analyzing",
    "message": "AI analysis initiated"
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### POST /api/records/incidents/:id/heal

Trigger auto-heal for an incident.

**Response:**
```json
{
  "success": true,
  "data": {
    "incidentId": "INC-0041",
    "status": "Healing",
    "action": "Restart Service",
    "message": "Auto-heal initiated"
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Integrations

#### GET /api/records/integration-logs

Retrieve integration logs with optional filtering.

**Query Parameters:**
- `status` (optional): Filter by status (Success, Warning, Failed)
- `apiName` (optional): Filter by API name
- `limit` (optional): Maximum number of results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "LOG-001",
        "apiName": "Payment API",
        "status": "Failed",
        "responseTime": 8420,
        "errorMessage": "Connection pool exhausted",
        "timestamp": "2024-01-01T00:00:00.000Z",
        "retryCount": 0
      }
    ],
    "total": 1,
    "limit": 50,
    "offset": 0
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Analytics

#### GET /api/analytics/summary

Get analytics summary for dashboard.

**Response:**
```json
{
  "success": true,
  "data": {
    "criticalIncidents": 2,
    "openIncidents": 5,
    "failedIntegrations": 3,
    "warningIntegrations": 2,
    "usersAffected": 2155,
    "revenueAtRisk": 90630,
    "autoHealed": 12
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### GET /api/analytics/trends

Get trend data for charts.

**Query Parameters:**
- `period` (optional): Time period (24h, 7d, 30d, default: 24h)
- `metric` (optional): Metric to retrieve (incidents, integrations, responseTime, default: incidents)

**Response:**
```json
{
  "success": true,
  "data": {
    "period": "24h",
    "metric": "incidents",
    "dataPoints": [
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "value": 5
      },
      {
        "timestamp": "2024-01-01T01:00:00.000Z",
        "value": 3
      }
    ]
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Sync

#### POST /api/sync/salesforce

Trigger synchronization with Salesforce.

**Request Body:**
```json
{
  "type": "incidents",
  "options": {
    "fullSync": false
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "syncId": "SYNC-001",
    "status": "Started",
    "type": "incidents",
    "message": "Synchronization initiated"
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### GET /api/sync/status/:syncId

Get synchronization status.

**Response:**
```json
{
  "success": true,
  "data": {
    "syncId": "SYNC-001",
    "status": "Completed",
    "type": "incidents",
    "recordsProcessed": 50,
    "recordsSucceeded": 48,
    "recordsFailed": 2,
    "startedAt": "2024-01-01T00:00:00.000Z",
    "completedAt": "2024-01-01T00:01:00.000Z",
    "errors": [
      {
        "recordId": "INC-9999",
        "error": "Record not found"
      }
    ]
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Error Codes

| Code | Description |
|------|-------------|
| AUTH_REQUIRED | Authentication required |
| AUTH_FAILED | Authentication failed |
| INVALID_TOKEN | Invalid or expired token |
| PERMISSION_DENIED | Insufficient permissions |
| INVALID_REQUEST | Invalid request parameters |
| RESOURCE_NOT_FOUND | Requested resource not found |
| INTERNAL_ERROR | Internal server error |
| SERVICE_UNAVAILABLE | Service temporarily unavailable |
| RATE_LIMIT_EXCEEDED | Rate limit exceeded |

## Rate Limiting

API requests are rate limited to prevent abuse:
- Default: 1000 requests per hour per user
- Rate limit headers are included in responses:
  - `X-RateLimit-Limit`: Request limit
  - `X-RateLimit-Remaining`: Remaining requests
  - `X-RateLimit-Reset`: Unix timestamp when limit resets

## Versioning

The API is versioned via the URL path. Current version: v1

```
/api/v1/...
```

## Webhooks

### Webhook Endpoints

#### POST /api/billing/webhook

Stripe webhook endpoint for billing events. Requires raw body for signature verification.

**Headers:**
- `Content-Type: application/json`
- `Stripe-Signature`: Webhook signature

**Request Body:** Stripe event payload

**Response:**
```json
{
  "success": true,
  "data": {
    "eventId": "evt_1234567890",
    "processed": true
  },
  "error": null,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Best Practices

1. **Always check the `success` field** in responses before accessing data
2. **Handle errors gracefully** using the error object in responses
3. **Use pagination** for large datasets
4. **Cache responses** where appropriate to reduce load
5. **Implement retry logic** with exponential backoff for failed requests
6. **Monitor rate limits** using response headers
7. **Use appropriate HTTP methods** (GET for retrieval, POST for creation, etc.)
8. **Validate input data** before sending requests
9. **Keep authentication tokens secure** and never expose them in client-side code
10. **Log API errors** for debugging and monitoring

## Support

For API-related issues or questions:
- Check the troubleshooting guide: [docs/portal-login-troubleshooting.md](portal-login-troubleshooting.md)
- Review the architecture documentation: [docs/architecture.md](architecture.md)
- Contact the development team
