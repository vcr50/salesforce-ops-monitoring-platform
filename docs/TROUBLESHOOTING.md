# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the subscription payment gateway system.

## Table of Contents

1. [Common Issues](#common-issues)
2. [Stripe-Related Issues](#stripe-related-issues)
3. [Webhook Issues](#webhook-issues)
4. [Subscription Issues](#subscription-issues)
5. [Customer Issues](#customer-issues)
6. [Payment Issues](#payment-issues)
7. [Performance Issues](#performance-issues)
8. [Debugging Tools](#debugging-tools)

## Common Issues

### Server Won't Start

**Symptoms:**
- Server fails to start
- Error messages on startup
- Port already in use

**Solutions:**

1. Check if port is already in use:
```bash
# Linux/Mac
lsof -i :3000

# Windows
netstat -ano | findstr :3000
```

2. Kill the process using the port:
```bash
# Linux/Mac
kill -9 <PID>

# Windows
taskkill /PID <PID> /F
```

3. Verify environment variables:
```bash
echo $STRIPE_SECRET_KEY
echo $NODE_ENV
```

4. Check for missing dependencies:
```bash
npm install
```

### Environment Variables Not Loading

**Symptoms:**
- `undefined` values for environment variables
- Configuration errors

**Solutions:**

1. Verify `.env` file exists in project root
2. Check file permissions
3. Ensure no syntax errors in `.env`:
```bash
# Correct format
KEY=value

# Incorrect (no spaces around =)
KEY = value
```

4. Restart server after changing `.env`

### Module Not Found Errors

**Symptoms:**
- `Error: Cannot find module`
- Import errors

**Solutions:**

1. Install missing dependencies:
```bash
npm install <module-name>
```

2. Clear node_modules and reinstall:
```bash
rm -rf node_modules package-lock.json
npm install
```

3. Check import paths are correct
4. Verify module is in `package.json`

## Stripe-Related Issues

### Invalid API Key

**Symptoms:**
- `Invalid API Key provided` error
- Authentication failures

**Solutions:**

1. Verify API key in `.env`:
```env
STRIPE_SECRET_KEY=sk_test_...
```

2. Check you're using the correct key:
   - Test mode: `sk_test_...`
   - Live mode: `sk_live_...`

3. Regenerate key if compromised:
   - Go to Stripe Dashboard → Developers → API keys
   - Click "Roll key" to generate new key
   - Update `.env` with new key

### Price ID Not Found

**Symptoms:**
- `No such price: price_...` error
- Checkout session creation fails

**Solutions:**

1. Verify price ID in `.env`:
```env
STRIPE_PROFESSIONAL_PRICE_ID=price_...
```

2. Check price exists in Stripe Dashboard:
   - Go to Products
   - Find your product
   - Copy the correct Price ID

3. Ensure you're using the right mode:
   - Test prices for test mode
   - Live prices for live mode

### Rate Limiting

**Symptoms:**
- `Rate limit error` from Stripe
- Requests being throttled

**Solutions:**

1. Implement exponential backoff:
```javascript
async function withRetry(operation, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => 
        setTimeout(resolve, Math.pow(2, i) * 1000)
      );
    }
  }
}
```

2. Cache frequently accessed data
3. Batch operations when possible
4. Contact Stripe to increase limits if needed

## Webhook Issues

### Webhook Not Receiving Events

**Symptoms:**
- Events not showing in logs
- Subscriptions not syncing
- Payment status not updating

**Solutions:**

1. Verify webhook endpoint is accessible:
```bash
curl -X POST https://your-domain.com/api/billing/webhook
```

2. Check webhook configuration in Stripe Dashboard:
   - Go to Developers → Webhooks
   - Verify endpoint URL is correct
   - Check selected events

3. Test webhook delivery:
   - In Stripe Dashboard, click "Send test webhook"
   - Check server logs for received event

4. Verify webhook secret:
```env
STRIPE_WEBHOOK_SECRET=whsec_...
```

### Webhook Signature Verification Failed

**Symptoms:**
- `No signatures found matching the expected signature` error
- Webhook events rejected

**Solutions:**

1. Verify webhook secret in `.env` matches Stripe Dashboard
2. Ensure you're using the correct secret:
   - Test mode: test webhook secret
   - Live mode: live webhook secret

3. Check raw body is being passed:
```javascript
app.use('/api/billing/webhook', express.raw({ type: 'application/json' }));
```

4. Verify signature extraction:
```javascript
const signature = req.headers['stripe-signature'];
```

### Webhook Processing Fails

**Symptoms:**
- Webhook received but not processed
- Errors in server logs
- Data not syncing to Salesforce

**Solutions:**

1. Check server logs for error details
2. Verify Salesforce credentials:
```env
SALESFORCE_INSTANCE_URL=https://...
SALESFORCE_ACCESS_TOKEN=...
```

3. Test Salesforce connection independently
4. Implement retry logic for failed events
5. Use Stripe CLI to test locally:
```bash
stripe listen --forward-to localhost:3000/api/billing/webhook
stripe trigger checkout.session.completed
```

## Subscription Issues

### Subscription Not Created

**Symptoms:**
- Checkout completes but no subscription
- Customer not charged

**Solutions:**

1. Check Stripe Dashboard for the session:
   - Go to Payments → Checkout Sessions
   - Find the session by ID
   - Check if subscription was created

2. Verify webhook events:
   - `checkout.session.completed` should be received
   - Check if subscription ID is present

3. Review customer's subscriptions:
   - Go to Customers → Select customer
   - Check Subscriptions section

4. Check server logs for errors during webhook processing

### Subscription Status Not Updating

**Symptoms:**
- Status shows as incorrect
- Changes not reflected in system

**Solutions:**

1. Verify webhook events are being received:
   - `customer.subscription.updated`
   - `invoice.paid`
   - `invoice.payment_failed`

2. Check Salesforce sync is working:
   - Review sync service logs
   - Verify Salesforce API credentials

3. Manually refresh subscription data:
```javascript
const subscription = await stripe.subscriptions.retrieve(subscriptionId);
```

4. Check for race conditions in webhook processing

### Plan Change Fails

**Symptoms:**
- Unable to change plan
- Error during plan update

**Solutions:**

1. Verify new plan ID exists
2. Check customer has active subscription
3. Verify subscription is not in past-due status
4. Check for proration issues:
```javascript
const subscription = await stripe.subscriptions.update(subscriptionId, {
  items: [{
    id: subscription.items.data[0].id,
    price: newPriceId
  }],
  proration_behavior: 'create_prorations'
});
```

## Customer Issues

### Customer Not Found

**Symptoms:**
- `Customer not found` error
- Unable to create subscription

**Solutions:**

1. Verify customer ID is correct
2. Check customer exists in Stripe Dashboard
3. Ensure customer was created successfully:
```javascript
const customer = await stripe.customers.create({
  email: 'user@example.com',
  metadata: { orgId: 'org_123' }
});
```

4. Use get-or-create endpoint for idempotency

### Duplicate Customers

**Symptoms:**
- Multiple customers for same organization
- Confusion in billing

**Solutions:**

1. Always use `getOrCreateCustomer` service
2. Check for existing customer before creating:
```javascript
const existingCustomer = await findCustomerByOrgId(orgId);
if (existingCustomer) {
  return existingCustomer;
}
```

3. Implement customer deduplication logic
4. Merge duplicate customers if needed

## Payment Issues

### Payment Failed

**Symptoms:**
- `invoice.payment_failed` webhook
- Customer charged but payment failed

**Solutions:**

1. Check Stripe Dashboard for payment details:
   - Go to Payments
   - Find the failed payment
   - Review failure reason

2. Common failure reasons:
   - Insufficient funds
   - Card declined
   - Expired card
   - Incorrect CVC

3. Notify customer to update payment method
4. Set up dunning emails in Stripe

### Payment Method Not Saved

**Symptoms:**
- Payment method not saved for future use
- Customer must re-enter card details

**Solutions:**

1. Verify setup intent is created:
```javascript
const setupIntent = await stripe.setupIntents.create({
  customer: customerId,
  payment_method_types: ['card']
});
```

2. Check customer has default payment method:
```javascript
const customer = await stripe.customers.retrieve(customerId);
console.log(customer.invoice_settings.default_payment_method);
```

3. Verify payment method is attached to customer:
```javascript
await stripe.paymentMethods.attach(paymentMethodId, {
  customer: customerId
});
```

## Performance Issues

### Slow API Responses

**Symptoms:**
- High response times
- Timeout errors
- Poor user experience

**Solutions:**

1. Identify slow endpoints:
   - Use APM tools (New Relic, Datadog)
   - Check server logs
   - Profile with Node.js profiler

2. Optimize database queries:
   - Add indexes
   - Use query optimization
   - Implement caching

3. Implement caching:
```javascript
const cached = await redis.get(`subscription:${subscriptionId}`);
if (cached) {
  return JSON.parse(cached);
}
```

4. Add more server instances if needed

### High Memory Usage

**Symptoms:**
- Server crashes
- Out of memory errors
- Slow performance

**Solutions:**

1. Monitor memory usage:
```javascript
const used = process.memoryUsage();
console.log(`Memory: ${Math.round(used.rss / 1024 / 1024)}MB`);
```

2. Identify memory leaks:
   - Use Node.js heap profiler
   - Check for event listener leaks
   - Review cache implementation

3. Implement memory limits:
```javascript
// In Kubernetes
resources:
  limits:
    memory: "512Mi"
```

4. Add more memory or optimize code

## Debugging Tools

### Stripe CLI

Test webhooks locally:

```bash
# Install
npm install -g stripe-cli

# Login
stripe login

# Forward webhooks
stripe listen --forward-to localhost:3000/api/billing/webhook

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger invoice.paid
stripe trigger customer.subscription.updated
```

### Server Logs

Enable detailed logging:

```javascript
const { logger } = require('./middleware/logger');

logger.info({
  event: 'subscription_created',
  subscriptionId: 'sub_123',
  customerId: 'cus_123'
});
```

### Database Query Logging

Log slow queries:

```javascript
const query = 'SELECT * FROM subscriptions WHERE id = ?';
const start = Date.now();

db.query(query, [subscriptionId], (err, results) => {
  const duration = Date.now() - start;
  if (duration > 1000) {
    logger.warn({ query, duration }, 'Slow query detected');
  }
});
```

### APM Tools

Integrate APM for monitoring:

```javascript
// New Relic
require('newrelic');

// Datadog
const tracer = require('dd-trace').init();
```

## Getting Help

If you can't resolve an issue:

1. Check Stripe documentation: https://stripe.com/docs
2. Review server logs for error details
3. Search existing issues
4. Contact support with:
   - Error messages
   - Server logs
   - Steps to reproduce
   - Environment details
