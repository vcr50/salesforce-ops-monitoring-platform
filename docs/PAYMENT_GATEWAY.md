# Subscription Payment Gateway System

## Overview

This document describes the subscription payment gateway system for SentinelFlow. The default provider is Stripe Checkout configured for card payments such as Visa, with the Razorpay path retained as an optional India subscription provider.

## Architecture

The payment gateway system consists of the following components:

### Services

- **customerService.js**: Handles Stripe customer creation, retrieval, and management
- **subscriptionService.js**: Manages plan metadata and Stripe subscription lifecycle operations
- **razorpayService.js**: Optional Razorpay customer/subscription creation and webhook signature checks
- **customerPortalService.js**: Handles Stripe Customer Portal operations
- **subscriptionSyncService.js**: Syncs subscription data with Salesforce

### Controllers

- **customerController.js**: HTTP request handlers for customer operations
- **subscriptionController.js**: HTTP request handlers for subscription operations
- **billingController.js**: HTTP request handlers for billing and checkout operations

### Routes

- **customers.js**: Customer-related API endpoints
- **subscriptions.js**: Subscription-related API endpoints
- **billing.js**: Billing and checkout API endpoints

## Features

### Customer Management

- Create new customers
- Retrieve customer information
- Update customer details
- Find customers by organization ID
- Get or create customers (idempotent operation)

### Subscription Management

- Create subscriptions for customers
- Retrieve subscription details
- Update subscription information
- Cancel subscriptions (immediate or at period end)
- Change subscription plans
- Get subscription usage statistics

### Billing Operations

- Create Stripe-hosted card checkout sessions for new subscriptions
- Handle Razorpay and Stripe webhooks
- Create customer portal sessions for self-service management
- Get customer invoices
- Get upcoming invoices
- Manage payment methods

### Plan Management

The system supports three subscription plans:

1. **Starter** (Free)
   - 5 integrations
   - Basic alerts
   - 7-day history
   - Email support

2. **Professional** ($29/month by default in the checkout UI)
   - 25 integrations
   - Agentforce AI
   - Business impact
   - 30-day history
   - Priority support

3. **Enterprise** ($149/month)
   - Unlimited integrations
   - Auto-heal
   - Custom runbooks
   - Unlimited history
   - Dedicated success manager

## API Endpoints

### Customer Endpoints

```
POST   /api/customers                    - Create a new customer
GET    /api/customers/:customerId         - Get customer by ID
PATCH  /api/customers/:customerId         - Update customer
DELETE /api/customers/:customerId         - Delete customer
GET    /api/customers/org/:orgId          - Find customer by org ID
POST   /api/customers/get-or-create       - Get or create customer
```

### Subscription Endpoints

```
GET    /api/subscriptions/plans                          - Get all plans
GET    /api/subscriptions/plans/:planId                  - Get plan by ID
POST   /api/subscriptions                                - Create subscription
GET    /api/subscriptions/:subscriptionId                - Get subscription
PATCH  /api/subscriptions/:subscriptionId                - Update subscription
POST   /api/subscriptions/:subscriptionId/cancel         - Cancel subscription
POST   /api/subscriptions/:subscriptionId/change-plan    - Change plan
GET    /api/subscriptions/:subscriptionId/usage          - Get usage stats
POST   /api/subscriptions/portal                         - Create portal session
GET    /api/subscriptions/customer/:customerId           - Get customer subscription
GET    /api/subscriptions/customer/:customerId/payment-methods  - Get payment methods
GET    /api/subscriptions/customer/:customerId/invoices  - Get invoices
GET    /api/subscriptions/customer/:customerId/upcoming-invoice  - Get upcoming invoice
```

### Billing Endpoints

```
POST   /api/billing/create-checkout-session  - Create checkout session
POST   /api/billing/portal                   - Create portal session
POST   /api/billing/webhook                  - Handle Stripe webhooks
```

## Environment Variables

Required environment variables:

```env
BILLING_PROVIDER=stripe
BILLING_CURRENCY=INR
PROFESSIONAL_MONTHLY_AMOUNT_INR=2499
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PROFESSIONAL_PRICE_ID=price_...
BILLING_RETURN_BASE_URL=https://your-domain.com
SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com
SALESFORCE_ACCESS_TOKEN=your-salesforce-token
```

## Webhook Events

The default Stripe card flow handles the following webhook events:

- `checkout.session.completed` - New subscription created
- `invoice.paid` - Payment successful
- `invoice.payment_failed` - Payment failed
- `customer.subscription.updated` - Subscription updated
- `customer.subscription.deleted` - Subscription cancelled

The optional Razorpay flow handles the following webhook events:

- `subscription.authenticated` - Mandate authorized
- `subscription.activated` - Subscription active
- `subscription.charged` - Recurring payment successful
- `subscription.pending` - Subscription pending
- `subscription.halted` - Payment collection halted
- `subscription.cancelled` - Subscription cancelled
- `subscription.completed` / `subscription.expired` - Subscription ended
- `payment.failed` - Payment failed

Recognized subscription webhook events are synced to Salesforce for record keeping.
When a website-originated buyer uses a temporary `web-lead:<email>` billing reference and the subscription first becomes `Active`, Salesforce sends an installation email to that email address with the selected plan, paid amount, terms/contact links, and the configured Salesforce package install URL.

## Integration Guide

### Creating a Checkout Session

```javascript
const response = await fetch('/api/billing/create-checkout-session', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    orgId: 'org_123',
    email: 'user@example.com',
    name: 'John Doe',
    plan: 'Professional'
  })
});

const { url } = await response.json();
window.location.href = url; // Redirect to Stripe card checkout
```

### Creating a Portal Session

```javascript
const response = await fetch('/api/billing/portal', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    orgId: 'org_123'
  })
});

const { url } = await response.json();
window.location.href = url; // Redirect to Customer Portal
```

### Getting Subscription Details

```javascript
const response = await fetch('/api/subscriptions/customer/cus_123');
const { data } = await response.json();
const subscription = data.subscription;
console.log('Status:', subscription.status);
console.log('Plan:', subscription.metadata.plan);
```

## Error Handling

All API endpoints return consistent error responses:

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

Common error codes:
- `400` - Bad Request (missing or invalid parameters)
- `404` - Not Found (customer/subscription not found)
- `500` - Internal Server Error (Stripe API errors, etc.)

## Security Considerations

1. Always use HTTPS for all API calls
2. Validate webhook signatures to ensure requests are from Stripe or Razorpay
3. Never expose secret keys in frontend code
4. Use environment variables for sensitive configuration
5. Never collect raw card details in SentinelFlow UI; use Stripe-hosted checkout for Visa/card entry
6. Implement proper authentication and authorization for API endpoints

## Monitoring and Logging

All operations are logged with relevant context:
- Customer ID and organization ID
- Subscription ID and plan details
- Billing event types
- Error details and stack traces

Logs are structured JSON for easy parsing and analysis.

## Testing

For testing purposes, you can use Stripe test mode with test card numbers:
- Success: `4242 4242 4242 4242`
- Requires 3D Secure: `4000 0025 0000 3155`
- Declined: `4000 0000 0000 0002`

## Support

For issues or questions about the payment gateway system, please contact the development team or refer to the Stripe documentation at https://stripe.com/docs.
