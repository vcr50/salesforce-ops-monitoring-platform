# Quick Start Guide

This guide will help you quickly set up and start using the subscription payment gateway system.

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- Stripe account ([sign up here](https://stripe.com))
- Salesforce account (for subscription sync)

## Installation

1. **Install Dependencies**

```bash
npm install stripe axios express
```

2. **Configure Environment Variables**

Copy the example environment file and update it with your credentials:

```bash
cp .env.example .env
```

Update `.env` with your actual values:

```env
STRIPE_SECRET_KEY=sk_test_your_actual_secret_key
STRIPE_PUBLISHABLE_KEY=pk_test_your_actual_publishable_key
STRIPE_WEBHOOK_SECRET=whsec_your_actual_webhook_secret
STRIPE_PROFESSIONAL_PRICE_ID=price_your_actual_price_id
BILLING_RETURN_BASE_URL=https://your-domain.com
SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com
SALESFORCE_ACCESS_TOKEN=your_actual_token
```

## Stripe Setup

### 1. Get API Keys

1. Log in to your [Stripe Dashboard](https://dashboard.stripe.com)
2. Go to Developers → API keys
3. Copy your Secret key and Publishable key
4. Add them to your `.env` file

### 2. Create Products and Prices

1. In Stripe Dashboard, go to Products
2. Create three products:
   - Starter (Free)
   - Professional ($49/month)
   - Enterprise ($149/month)
3. For each product, create a monthly price
4. Copy the Price IDs and add them to your `.env` file

### 3. Set Up Webhook

1. In Stripe Dashboard, go to Developers → Webhooks
2. Click "Add endpoint"
3. Set endpoint URL to: `https://your-domain.com/api/billing/webhook`
4. Select these events to listen for:
   - `checkout.session.completed`
   - `invoice.paid`
   - `invoice.payment_failed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Copy the webhook signing secret and add it to `.env`

## Server Setup

### 1. Mount Routes

In your main application file (e.g., `app.js` or `server.js`):

```javascript
const express = require('express');
const billingRoutes = require('./src/routes/billing');
const customerRoutes = require('./src/routes/customers');
const subscriptionRoutes = require('./src/routes/subscriptions');

const app = express();

// Middleware
app.use(express.json());
app.use(express.raw({ type: 'application/json' })); // For webhooks

// Routes
app.use('/api/billing', billingRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/subscriptions', subscriptionRoutes);

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 2. Test the Server

Start your server:

```bash
npm start
```

Test the health endpoint:

```bash
curl http://localhost:3000/api/subscriptions/plans
```

You should receive a JSON response with available plans.

## Frontend Integration

### 1. Add Stripe.js

```html
<script src="https://js.stripe.com/v3/"></script>
```

### 2. Initialize Stripe

```javascript
const stripe = Stripe(process.env.STRIPE_PUBLISHABLE_KEY);
```

### 3. Create Checkout Button

```javascript
async function startCheckout() {
  try {
    const response = await fetch('/api/billing/create-checkout-session', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        orgId: 'your-org-id',
        email: 'user@example.com',
        name: 'John Doe',
        plan: 'Professional'
      })
    });

    const { url } = await response.json();
    window.location.href = url;
  } catch (error) {
    console.error('Checkout failed:', error);
    alert('Failed to start checkout');
  }
}

// Add to your HTML
<button onclick="startCheckout()">Subscribe Now</button>
```

## Testing

### Test Mode

Stripe provides test mode for development. Use these test card numbers:

- **Success**: `4242 4242 4242 4242`
- **Requires 3D Secure**: `4000 0025 0000 3155`
- **Declined**: `4000 0000 0000 0002`
- **Insufficient Funds**: `4000 0000 0000 9995`

### Test Webhooks Locally

Use the Stripe CLI to test webhooks locally:

```bash
# Install Stripe CLI
npm install -g stripe-cli

# Login to Stripe
stripe login

# Forward webhooks to your local server
stripe listen --forward-to localhost:3000/api/billing/webhook
```

## Common Tasks

### Create a Customer

```javascript
const response = await fetch('/api/customers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'user@example.com',
    name: 'John Doe',
    orgId: 'org_123'
  })
});

const { data } = await response.json();
console.log('Customer ID:', data.customer.id);
```

### Get Subscription Status

```javascript
const response = await fetch('/api/subscriptions/customer/cus_123');
const { data } = await response.json();
console.log('Status:', data.subscription.status);
console.log('Plan:', data.subscription.metadata.plan);
```

### Open Customer Portal

```javascript
const response = await fetch('/api/billing/portal', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ orgId: 'org_123' })
});

const { url } = await response.json();
window.location.href = url;
```

### Cancel Subscription

```javascript
const response = await fetch('/api/subscriptions/sub_123/cancel', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ immediate: false })
});

await response.json();
console.log('Subscription cancelled');
```

## Troubleshooting

### Webhook Not Receiving Events

1. Verify webhook URL is correct
2. Check webhook secret in `.env`
3. Ensure server is accessible from the internet
4. Use Stripe CLI for local testing

### Checkout Session Fails

1. Verify Stripe secret key is correct
2. Check price IDs are configured
3. Ensure customer is created successfully
4. Check server logs for error details

### Customer Not Found

1. Verify orgId is correct
2. Check customer was created successfully
3. Ensure metadata includes orgId

### Payment Failed

1. Check Stripe Dashboard for payment details
2. Verify webhook events are being received
3. Check customer's payment methods
4. Review invoice details in Stripe

## Next Steps

- Read the [Payment Gateway Documentation](./PAYMENT_GATEWAY.md)
- Check the [Frontend Integration Guide](./FRONTEND_INTEGRATION.md)
- Review the [API Reference](./API_REFERENCE.md)
- Set up monitoring and alerting
- Configure production environment

## Support

For issues or questions:
- Check Stripe documentation: https://stripe.com/docs
- Review server logs for error details
- Contact the development team

## Security Checklist

Before going to production:

- [ ] Use production Stripe keys
- [ ] Enable HTTPS
- [ ] Set up webhook signature verification
- [ ] Implement rate limiting
- [ ] Add authentication/authorization
- [ ] Enable logging and monitoring
- [ ] Set up error tracking
- [ ] Configure backup systems
- [ ] Review and test error handling
- [ ] Document deployment process
