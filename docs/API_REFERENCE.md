# API Reference

Complete API reference for the subscription payment gateway system.

## Base URL

```
https://your-api.com/api
```

## Authentication

All API endpoints require authentication. Include your API key in the request headers:

```
Authorization: Bearer your_api_key
```

## Response Format

All responses follow this format:

### Success Response

```json
{
  "success": true,
  "data": {
    // Response data here
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

## Customer Endpoints

### Create Customer

Creates a new customer in Stripe.

**Endpoint:** `POST /customers`

**Request Body:**

```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "orgId": "org_123",
  "metadata": {
    "customField": "value"
  }
}
```

**Required Fields:**
- `email` (string) - Customer's email address
- `orgId` (string) - Organization ID

**Optional Fields:**
- `name` (string) - Customer's name
- `metadata` (object) - Additional metadata

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "email": "user@example.com",
      "name": "John Doe",
      "metadata": {
        "orgId": "org_123"
      }
    }
  }
}
```

**Error Codes:**
- `400` - Missing required fields
- `500` - Server error

---

### Get Customer

Retrieves a customer by ID.

**Endpoint:** `GET /customers/:customerId`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "email": "user@example.com",
      "name": "John Doe",
      "metadata": {
        "orgId": "org_123"
      }
    }
  }
}
```

**Error Codes:**
- `404` - Customer not found
- `500` - Server error

---

### Update Customer

Updates customer information.

**Endpoint:** `PATCH /customers/:customerId`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Request Body:**

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "metadata": {
    "updated": true
  }
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "email": "jane@example.com",
      "name": "Jane Doe"
    }
  }
}
```

**Error Codes:**
- `400` - Invalid data
- `404` - Customer not found
- `500` - Server error

---

### Delete Customer

Deletes a customer.

**Endpoint:** `DELETE /customers/:customerId`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "deleted": true
    }
  }
}
```

**Error Codes:**
- `404` - Customer not found
- `500` - Server error

---

### Find Customer by Organization ID

Finds a customer by their organization ID.

**Endpoint:** `GET /customers/org/:orgId`

**Path Parameters:**
- `orgId` (string) - Organization ID

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "email": "user@example.com",
      "metadata": {
        "orgId": "org_123"
      }
    }
  }
}
```

**Error Codes:**
- `404` - Customer not found
- `500` - Server error

---

### Get or Create Customer

Gets an existing customer or creates a new one if not found.

**Endpoint:** `POST /customers/get-or-create`

**Request Body:**

```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "orgId": "org_123"
}
```

**Required Fields:**
- `email` (string) - Customer's email address
- `orgId` (string) - Organization ID

**Optional Fields:**
- `name` (string) - Customer's name

**Response:**

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "cus_1234567890",
      "email": "user@example.com",
      "name": "John Doe",
      "metadata": {
        "orgId": "org_123"
      }
    }
  }
}
```

**Error Codes:**
- `400` - Missing required fields
- `500` - Server error

---

## Subscription Endpoints

### Get All Plans

Retrieves all available subscription plans.

**Endpoint:** `GET /subscriptions/plans`

**Response:**

```json
{
  "success": true,
  "data": {
    "plans": [
      {
        "id": "price_starter_monthly",
        "name": "Starter",
        "price": 0,
        "interval": "month",
        "features": [
          "5 integrations",
          "Basic alerts",
          "7-day history",
          "Email support"
        ],
        "limits": {
          "integrations": 5,
          "historyDays": 7,
          "users": 1
        }
      }
    ]
  }
}
```

**Error Codes:**
- `500` - Server error

---

### Get Plan by ID

Retrieves a specific plan by ID.

**Endpoint:** `GET /subscriptions/plans/:planId`

**Path Parameters:**
- `planId` (string) - Plan ID

**Response:**

```json
{
  "success": true,
  "data": {
    "plan": {
      "id": "price_professional_monthly",
      "name": "Professional",
      "price": 49,
      "interval": "month",
      "features": [
        "25 integrations",
        "Agentforce AI",
        "Business impact",
        "30-day history",
        "Priority support"
      ],
      "limits": {
        "integrations": 25,
        "historyDays": 30,
        "users": 5
      }
    }
  }
}
```

**Error Codes:**
- `404` - Plan not found
- `500` - Server error

---

### Create Subscription

Creates a new subscription for a customer.

**Endpoint:** `POST /subscriptions`

**Request Body:**

```json
{
  "customerId": "cus_1234567890",
  "planId": "price_professional_monthly",
  "orgId": "org_123",
  "email": "user@example.com"
}
```

**Required Fields:**
- `customerId` (string) - Stripe customer ID
- `planId` (string) - Plan ID

**Optional Fields:**
- `orgId` (string) - Organization ID
- `email` (string) - Customer email

**Response:**

```json
{
  "success": true,
  "data": {
    "subscriptionId": "sub_1234567890",
    "status": "active",
    "clientSecret": "pi_1234567890_secret_xyz"
  }
}
```

**Error Codes:**
- `400` - Missing required fields or invalid data
- `500` - Server error

---

### Get Subscription

Retrieves subscription details.

**Endpoint:** `GET /subscriptions/:subscriptionId`

**Path Parameters:**
- `subscriptionId` (string) - Stripe subscription ID

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "sub_1234567890",
      "status": "active",
      "current_period_end": 1234567890,
      "metadata": {
        "plan": "Professional",
        "orgId": "org_123"
      }
    }
  }
}
```

**Error Codes:**
- `404` - Subscription not found
- `500` - Server error

---

### Update Subscription

Updates subscription information.

**Endpoint:** `PATCH /subscriptions/:subscriptionId`

**Path Parameters:**
- `subscriptionId` (string) - Stripe subscription ID

**Request Body:**

```json
{
  "metadata": {
    "updated": true
  },
  "cancel_at_period_end": false
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "sub_1234567890",
      "status": "active",
      "metadata": {
        "updated": true
      }
    }
  }
}
```

**Error Codes:**
- `400` - Invalid data
- `404` - Subscription not found
- `500` - Server error

---

### Cancel Subscription

Cancels a subscription.

**Endpoint:** `POST /subscriptions/:subscriptionId/cancel`

**Path Parameters:**
- `subscriptionId` (string) - Stripe subscription ID

**Request Body:**

```json
{
  "immediate": false
}
```

**Optional Fields:**
- `immediate` (boolean) - Cancel immediately (default: false)

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "sub_1234567890",
      "status": "canceled",
      "cancel_at": 1234567890
    }
  }
}
```

**Error Codes:**
- `404` - Subscription not found
- `500` - Server error

---

### Change Plan

Changes a subscription to a different plan.

**Endpoint:** `POST /subscriptions/:subscriptionId/change-plan`

**Path Parameters:**
- `subscriptionId` (string) - Stripe subscription ID

**Request Body:**

```json
{
  "newPlanId": "price_enterprise_monthly"
}
```

**Required Fields:**
- `newPlanId` (string) - New plan ID

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "sub_1234567890",
      "status": "active",
      "items": [
        {
          "price": {
            "id": "price_enterprise_monthly",
            "nickname": "Enterprise"
          }
        }
      ]
    }
  }
}
```

**Error Codes:**
- `400` - Missing required fields or invalid plan
- `404` - Subscription not found
- `500` - Server error

---

### Get Usage Statistics

Retrieves usage statistics for a subscription.

**Endpoint:** `GET /subscriptions/:subscriptionId/usage`

**Path Parameters:**
- `subscriptionId` (string) - Stripe subscription ID

**Response:**

```json
{
  "success": true,
  "data": {
    "stats": {
      "integrations": 15,
      "integrationsLimit": 25,
      "users": 3,
      "usersLimit": 5,
      "historyDays": 30,
      "historyDaysLimit": 30
    }
  }
}
```

**Error Codes:**
- `404` - Subscription not found
- `500` - Server error

---

### Get Customer Subscription

Retrieves subscription for a customer.

**Endpoint:** `GET /subscriptions/customer/:customerId`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "sub_1234567890",
      "status": "active",
      "metadata": {
        "plan": "Professional"
      }
    }
  }
}
```

**Error Codes:**
- `404` - Subscription not found
- `500` - Server error

---

### Get Payment Methods

Retrieves payment methods for a customer.

**Endpoint:** `GET /subscriptions/customer/:customerId/payment-methods`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Response:**

```json
{
  "success": true,
  "data": {
    "paymentMethods": [
      {
        "id": "pm_1234567890",
        "type": "card",
        "card": {
          "brand": "visa",
          "last4": "4242",
          "exp_month": 12,
          "exp_year": 2024
        }
      }
    ]
  }
}
```

**Error Codes:**
- `500` - Server error

---

### Get Invoices

Retrieves invoices for a customer.

**Endpoint:** `GET /subscriptions/customer/:customerId/invoices`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Query Parameters:**
- `limit` (number, optional) - Number of invoices to return (default: 10)

**Response:**

```json
{
  "success": true,
  "data": {
    "invoices": [
      {
        "id": "in_1234567890",
        "amount_paid": 4900,
        "currency": "usd",
        "status": "paid",
        "created": 1234567890
      }
    ],
    "has_more": true
  }
}
```

**Error Codes:**
- `500` - Server error

---

### Get Upcoming Invoice

Retrieves the upcoming invoice for a customer.

**Endpoint:** `GET /subscriptions/customer/:customerId/upcoming-invoice`

**Path Parameters:**
- `customerId` (string) - Stripe customer ID

**Query Parameters:**
- `subscriptionId` (string, optional) - Stripe subscription ID

**Response:**

```json
{
  "success": true,
  "data": {
    "invoice": {
      "id": "in_upcoming_1234567890",
      "amount_due": 4900,
      "currency": "usd",
      "next_payment_attempt": 1234567890
    }
  }
}
```

**Error Codes:**
- `500` - Server error

---

## Billing Endpoints

### Create Checkout Session

Creates a Stripe Checkout session for a new subscription.

**Endpoint:** `POST /billing/create-checkout-session`

**Request Body:**

```json
{
  "orgId": "org_123",
  "email": "user@example.com",
  "name": "John Doe",
  "plan": "Professional"
}
```

**Required Fields:**
- `orgId` (string) - Organization ID
- `email` (string) - Customer email

**Optional Fields:**
- `name` (string) - Customer name
- `plan` (string) - Plan name (default: "Professional")

**Response:**

```json
{
  "sessionId": "cs_1234567890",
  "url": "https://checkout.stripe.com/c/pay/cs_1234567890"
}
```

**Error Codes:**
- `400` - Missing required fields or invalid plan
- `500` - Server error

---

### Create Portal Session

Creates a Stripe Customer Portal session.

**Endpoint:** `POST /billing/portal`

**Request Body:**

```json
{
  "orgId": "org_123"
}
```

**Required Fields:**
- `orgId` (string) - Organization ID

**Response:**

```json
{
  "url": "https://billing.stripe.com/session/1234567890"
}
```

**Error Codes:**
- `400` - Missing required fields
- `404` - Customer not found
- `500` - Server error

---

### Handle Webhook

Processes Stripe webhook events.

**Endpoint:** `POST /billing/webhook`

**Headers:**
- `stripe-signature` (string) - Stripe webhook signature

**Request Body:**
Raw webhook event payload from Stripe

**Response:**

```json
{
  "received": true
}
```

**Error Codes:**
- `400` - Invalid webhook signature
- `500` - Server error

**Supported Events:**
- `checkout.session.completed`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.updated`
- `customer.subscription.deleted`

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request - Invalid or missing parameters |
| 401 | Unauthorized - Invalid or missing authentication |
| 404 | Not Found - Resource doesn't exist |
| 500 | Internal Server Error - Server-side error |

## Rate Limiting

API endpoints are rate limited to prevent abuse:

- Standard endpoints: 100 requests per minute
- Webhook endpoints: 1000 requests per minute

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1234567890
```

## Pagination

For endpoints that return lists, use these query parameters:

- `limit` (number) - Number of items to return (max: 100)
- `starting_after` (string) - Cursor for pagination

Example:
```
GET /subscriptions/customer/:customerId/invoices?limit=20&starting_after=in_123
```

## Versioning

API versioning is handled via the `Accept` header:

```
Accept: application/vnd.api+json; version=1
```

## SDKs

Official SDKs are available for:

- JavaScript/Node.js
- Python
- Ruby
- Go
- Java

See the [Stripe SDKs](https://stripe.com/docs/libraries) for more information.
