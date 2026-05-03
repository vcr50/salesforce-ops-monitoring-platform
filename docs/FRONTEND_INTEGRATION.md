# Frontend Integration Guide

This guide provides examples and best practices for integrating the subscription payment gateway into your frontend application.

## Table of Contents

1. [Setup](#setup)
2. [Checkout Flow](#checkout-flow)
3. [Customer Portal](#customer-portal)
4. [Subscription Management](#subscription-management)
5. [Error Handling](#error-handling)
6. [Best Practices](#best-practices)

## Setup

### 1. Include Stripe.js

Add Stripe.js to your HTML:

```html
<script src="https://js.stripe.com/v3/"></script>
```

### 2. Initialize Stripe

```javascript
const stripe = Stripe('your_publishable_key');
```

### 3. Create API Client

```javascript
// api.js
const API_BASE_URL = process.env.API_BASE_URL || 'https://your-api.com/api';

class BillingAPI {
  async request(endpoint, options = {}) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Request failed');
    }

    return response.json();
  }

  async createCheckoutSession(data) {
    return this.request('/billing/create-checkout-session', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async createPortalSession(data) {
    return this.request('/billing/portal', {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }

  async getSubscription(customerId) {
    return this.request(`/subscriptions/customer/${customerId}`);
  }

  async getPlans() {
    return this.request('/subscriptions/plans');
  }

  async cancelSubscription(subscriptionId, immediate = false) {
    return this.request(`/subscriptions/${subscriptionId}/cancel`, {
      method: 'POST',
      body: JSON.stringify({ immediate })
    });
  }

  async changePlan(subscriptionId, newPlanId) {
    return this.request(`/subscriptions/${subscriptionId}/change-plan`, {
      method: 'POST',
      body: JSON.stringify({ newPlanId })
    });
  }
}

export const billingAPI = new BillingAPI();
```

## Checkout Flow

### Basic Checkout

```javascript
// checkout.js
import { billingAPI } from './api';

async function initiateCheckout(orgId, email, name, plan) {
  try {
    const { url } = await billingAPI.createCheckoutSession({
      orgId,
      email,
      name,
      plan
    });

    // Redirect to Stripe Checkout
    window.location.href = url;
  } catch (error) {
    console.error('Checkout failed:', error);
    // Show error to user
    showError('Failed to start checkout. Please try again.');
  }
}

// Usage
initiateCheckout('org_123', 'user@example.com', 'John Doe', 'Professional');
```

### Checkout with Loading State

```javascript
// checkout.js
import { billingAPI } from './api';

async function initiateCheckoutWithLoading(orgId, email, name, plan) {
  const button = document.getElementById('checkout-button');
  const originalText = button.textContent;

  try {
    // Show loading state
    button.disabled = true;
    button.textContent = 'Processing...';

    const { url } = await billingAPI.createCheckoutSession({
      orgId,
      email,
      name,
      plan
    });

    // Redirect to Stripe Checkout
    window.location.href = url;
  } catch (error) {
    console.error('Checkout failed:', error);
    showError('Failed to start checkout. Please try again.');

    // Reset button
    button.disabled = false;
    button.textContent = originalText;
  }
}
```

### Checkout with Plan Selection

```javascript
// checkout.js
import { billingAPI } from './api';

async function showPlanSelection(orgId, email, name) {
  try {
    const { data } = await billingAPI.getPlans();
    const plans = data.plans;

    // Render plan cards
    const plansContainer = document.getElementById('plans-container');
    plansContainer.innerHTML = plans.map(plan => `
      <div class="plan-card" data-plan="${plan.name}">
        <h3>${plan.name}</h3>
        <p class="price">$${plan.price}/${plan.interval}</p>
        <ul>
          ${plan.features.map(feature => `<li>${feature}</li>`).join('')}
        </ul>
        <button onclick="selectPlan('${plan.name}')">Choose ${plan.name}</button>
      </div>
    `).join('');

    // Store user data for checkout
    window.checkoutData = { orgId, email, name };
  } catch (error) {
    console.error('Failed to load plans:', error);
    showError('Failed to load plans. Please refresh the page.');
  }
}

async function selectPlan(planName) {
  const { orgId, email, name } = window.checkoutData;
  await initiateCheckout(orgId, email, name, planName);
}
```

## Customer Portal

### Open Portal

```javascript
// portal.js
import { billingAPI } from './api';

async function openCustomerPortal(orgId) {
  try {
    const { url } = await billingAPI.createPortalSession({ orgId });
    window.location.href = url;
  } catch (error) {
    console.error('Failed to open portal:', error);
    showError('Failed to open customer portal. Please try again.');
  }
}

// Usage
openCustomerPortal('org_123');
```

### Portal Button Component

```javascript
// PortalButton.js
import { billingAPI } from './api';

function PortalButton({ orgId, children = 'Manage Subscription' }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleClick = async () => {
    setLoading(true);
    setError(null);

    try {
      const { url } = await billingAPI.createPortalSession({ orgId });
      window.location.href = url;
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  return (
    <div>
      <button 
        onClick={handleClick}
        disabled={loading}
        className="portal-button"
      >
        {loading ? 'Loading...' : children}
      </button>
      {error && <div className="error">{error}</div>}
    </div>
  );
}
```

## Subscription Management

### Display Subscription Status

```javascript
// subscription.js
import { billingAPI } from './api';

async function displaySubscriptionStatus(customerId) {
  try {
    const { data } = await billingAPI.getSubscription(customerId);
    const subscription = data.subscription;

    const statusElement = document.getElementById('subscription-status');
    statusElement.innerHTML = `
      <div class="subscription-info">
        <h3>Current Plan: ${subscription.metadata.plan}</h3>
        <p>Status: ${subscription.status}</p>
        <p>Next billing: ${new Date(subscription.current_period_end * 1000).toLocaleDateString()}</p>
      </div>
    `;
  } catch (error) {
    console.error('Failed to get subscription:', error);
    showError('Failed to load subscription details.');
  }
}
```

### Cancel Subscription

```javascript
// subscription.js
import { billingAPI } from './api';

async function cancelSubscription(subscriptionId, immediate = false) {
  if (!confirm('Are you sure you want to cancel your subscription?')) {
    return;
  }

  try {
    await billingAPI.cancelSubscription(subscriptionId, immediate);
    showSuccess('Subscription cancelled successfully.');
    // Refresh subscription status
    displaySubscriptionStatus(customerId);
  } catch (error) {
    console.error('Cancellation failed:', error);
    showError('Failed to cancel subscription. Please try again.');
  }
}
```

### Change Plan

```javascript
// subscription.js
import { billingAPI } from './api';

async function changePlan(subscriptionId, newPlanId) {
  try {
    await billingAPI.changePlan(subscriptionId, newPlanId);
    showSuccess('Plan changed successfully.');
    // Refresh subscription status
    displaySubscriptionStatus(customerId);
  } catch (error) {
    console.error('Plan change failed:', error);
    showError('Failed to change plan. Please try again.');
  }
}
```

### Plan Change Confirmation

```javascript
// subscription.js
async function confirmPlanChange(subscriptionId, newPlanId, newPlanName) {
  const confirmed = confirm(
    `Are you sure you want to change to the ${newPlanName} plan?`
  );

  if (confirmed) {
    await changePlan(subscriptionId, newPlanId);
  }
}
```

## Error Handling

### Error Display Component

```javascript
// ErrorDisplay.js
function ErrorDisplay({ error }) {
  if (!error) return null;

  const errorMessages = {
    'orgId is required': 'Organization ID is required',
    'email is required': 'Email address is required',
    'Customer not found': 'No customer account found',
    'Invalid plan': 'Invalid subscription plan selected',
    'default': 'An error occurred. Please try again.'
  };

  const message = errorMessages[error] || errorMessages['default'];

  return (
    <div className="error-message">
      <span className="error-icon">⚠️</span>
      {message}
    </div>
  );
}
```

### Error Boundary (React)

```javascript
// ErrorBoundary.js
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h2>Something went wrong</h2>
          <p>{this.state.error?.message}</p>
          <button onClick={() => window.location.reload()}>
            Refresh Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

## Best Practices

### 1. Loading States

Always show loading indicators during async operations:

```javascript
const [loading, setLoading] = useState(false);

async function handleAction() {
  setLoading(true);
  try {
    await performAction();
  } finally {
    setLoading(false);
  }
}
```

### 2. Error Handling

Implement comprehensive error handling:

```javascript
try {
  const result = await billingAPI.someOperation();
  // Handle success
} catch (error) {
  // Log error
  console.error('Operation failed:', error);

  // Show user-friendly message
  showNotification(error.message || 'Operation failed');

  // Optionally report to error tracking service
  trackError(error);
}
```

### 3. User Confirmation

Require confirmation for destructive actions:

```javascript
async function handleDestructiveAction() {
  const confirmed = await showConfirmationDialog(
    'Are you sure you want to proceed? This action cannot be undone.'
  );

  if (!confirmed) return;

  await performAction();
}
```

### 4. Optimistic Updates

Update UI optimistically for better UX:

```javascript
async function updateSubscription(newPlan) {
  // Optimistically update UI
  setPreviousPlan(currentPlan);
  setCurrentPlan(newPlan);

  try {
    await billingAPI.changePlan(subscriptionId, newPlan);
  } catch (error) {
    // Revert on error
    setCurrentPlan(previousPlan);
    showError('Failed to update plan');
  }
}
```

### 5. Retry Logic

Implement retry for transient failures:

```javascript
async function withRetry(operation, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}
```

### 6. Session Management

Handle session expiration gracefully:

```javascript
async function authenticatedRequest(operation) {
  try {
    return await operation();
  } catch (error) {
    if (error.status === 401) {
      // Redirect to login
      window.location.href = '/login?redirect=' + encodeURIComponent(window.location.pathname);
      throw new Error('Session expired');
    }
    throw error;
  }
}
```

## Complete Example: Subscription Management Page

```javascript
// SubscriptionPage.js
import { useState, useEffect } from 'react';
import { billingAPI } from './api';

function SubscriptionPage({ orgId, customerId }) {
  const [subscription, setSubscription] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadSubscription();
  }, [customerId]);

  async function loadSubscription() {
    setLoading(true);
    setError(null);

    try {
      const { data } = await billingAPI.getSubscription(customerId);
      setSubscription(data.subscription);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleCancel() {
    if (!confirm('Are you sure you want to cancel?')) return;

    try {
      await billingAPI.cancelSubscription(subscription.id);
      await loadSubscription();
    } catch (err) {
      setError(err.message);
    }
  }

  async function handlePortal() {
    try {
      const { url } = await billingAPI.createPortalSession({ orgId });
      window.location.href = url;
    } catch (err) {
      setError(err.message);
    }
  }

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!subscription) return <div>No active subscription</div>;

  return (
    <div className="subscription-page">
      <h2>Subscription Details</h2>
      <div className="subscription-info">
        <p>Plan: {subscription.metadata.plan}</p>
        <p>Status: {subscription.status}</p>
        <p>Next billing: {new Date(subscription.current_period_end * 1000).toLocaleDateString()}</p>
      </div>

      <div className="subscription-actions">
        <button onClick={handlePortal}>Manage in Portal</button>
        <button onClick={handleCancel}>Cancel Subscription</button>
      </div>
    </div>
  );
}
```

## Support

For more information or assistance with integration, please refer to:
- [Stripe.js Documentation](https://stripe.com/docs/js)
- [Stripe Checkout Documentation](https://stripe.com/docs/payments/checkout)
- [API Reference](./PAYMENT_GATEWAY.md)
