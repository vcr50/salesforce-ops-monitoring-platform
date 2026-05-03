# Vanilla JavaScript Integration Example

This example demonstrates how to integrate the subscription payment gateway system using vanilla JavaScript.

## Features

- Display pricing plans with checkout functionality
- Manage existing subscriptions
- Change subscription plans
- Cancel subscriptions
- Access customer portal
- Beautiful, responsive UI
- No framework dependencies

## Prerequisites

- A modern web browser
- Web server (for serving the files)

## Installation

1. Navigate to the example directory:

```bash
cd examples/vanilla-js
```

2. Configure your API settings:

Edit `app.js` and update the CONFIG object:

```javascript
const CONFIG = {
  orgId: 'your-org-id',
  email: 'user@example.com',
  name: 'John Doe',
  customerId: 'cus_your-customer-id'
};
```

3. Set up your API base URL:

Edit `billing-api.js` and update the baseURL:

```javascript
this.baseURL = window.API_BASE_URL || 'https://your-api.com/api';
```

Or set it globally before loading the script:

```html
<script>
  window.API_BASE_URL = 'https://your-api.com/api';
</script>
<script src="billing-api.js"></script>
```

## Project Structure

```
vanilla-js/
├── index.html          # Main HTML file
├── styles.css          # Stylesheet
├── billing-api.js      # Billing API service
├── app.js              # Main application logic
└── README.md           # This file
```

## Usage

### Running Locally

You can use any web server to serve the files. Here are a few options:

**Option 1: Python Simple HTTP Server**

```bash
python -m http.server 8000
```

**Option 2: Node.js http-server**

```bash
npx http-server -p 8000
```

**Option 3: VS Code Live Server Extension**

Install the Live Server extension and right-click on `index.html` to open with Live Server.

Then open your browser to `http://localhost:8000`

### Integrating into Your Application

1. **Copy the files** to your project:
   - `styles.css`
   - `billing-api.js`
   - `app.js`

2. **Include the files** in your HTML:

```html
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <!-- Your content here -->

  <script src="billing-api.js"></script>
  <script src="app.js"></script>
</body>
</html>
```

3. **Configure** the API settings as described above

## Components

### BillingAPI Class

The `billing-api.js` file provides a `BillingAPI` class that handles all API communication.

**Available Methods:**

```javascript
// Checkout
await billingAPI.createCheckoutSession(data);
await billingAPI.createPortalSession(data);

// Plans
await billingAPI.getPlans();
await billingAPI.getPlanById(planId);

// Subscriptions
await billingAPI.createSubscription(data);
await billingAPI.getSubscription(subscriptionId);
await billingAPI.getCustomerSubscription(customerId);
await billingAPI.updateSubscription(subscriptionId, data);
await billingAPI.cancelSubscription(subscriptionId, immediate);
await billingAPI.changePlan(subscriptionId, newPlanId);
await billingAPI.getUsageStats(subscriptionId);

// Payment Methods
await billingAPI.getPaymentMethods(customerId);

// Invoices
await billingAPI.getInvoices(customerId, limit);
await billingAPI.getUpcomingInvoice(customerId, subscriptionId);

// Customers
await billingAPI.createCustomer(data);
await billingAPI.getCustomer(customerId);
await billingAPI.getCustomerByOrgId(orgId);
await billingAPI.updateCustomer(customerId, data);
await billingAPI.deleteCustomer(customerId);
await billingAPI.getOrCreateCustomer(data);
```

### Main Application

The `app.js` file handles:

- Tab navigation
- Loading and displaying plans
- Loading and displaying subscription information
- Plan selection and checkout
- Plan changes
- Subscription cancellation
- Customer portal access

## Customization

### Styling

All styles are in `styles.css`. You can customize:

- Colors (CSS variables at the top)
- Layout and spacing
- Typography
- Component styles

### Configuration

Update the `CONFIG` object in `app.js`:

```javascript
const CONFIG = {
  orgId: 'your-org-id',
  email: 'user@example.com',
  name: 'John Doe',
  customerId: 'cus_your-customer-id'
};
```

### API Endpoint

Set the API base URL:

```javascript
// In billing-api.js
this.baseURL = 'https://your-api.com/api';

// Or globally before loading the script
window.API_BASE_URL = 'https://your-api.com/api';
```

## Common Use Cases

### 1. Display Pricing Plans Only

Remove the subscription tab and related code from `index.html` and `app.js`.

### 2. Display Subscription Management Only

Remove the plans tab and related code from `index.html` and `app.js`.

### 3. Custom Integration

Use the `BillingAPI` class directly in your own application:

```javascript
// Initialize
const api = new BillingAPI();

// Get plans
const { data } = await api.getPlans();
console.log(data.plans);

// Create checkout session
const { url } = await api.createCheckoutSession({
  orgId: 'org_123',
  email: 'user@example.com',
  plan: 'Professional'
});
window.location.href = url;
```

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Troubleshooting

### API Not Working

1. Verify API base URL is correct
2. Check browser console for errors
3. Ensure your API server is running
4. Verify CORS is configured correctly

### Styles Not Loading

1. Verify `styles.css` is linked correctly
2. Check for CSS syntax errors
3. Clear browser cache
4. Check browser console for errors

### Checkout Not Working

1. Verify orgId and email are configured
2. Check API endpoint is accessible
3. Review browser console for errors
4. Ensure Stripe is properly configured

## Security Considerations

1. **Never expose secret keys** in client-side code
2. **Use HTTPS** in production
3. **Validate user input** on the server
4. **Implement authentication** for protected endpoints
5. **Use CORS** properly to control access

## Performance Tips

1. **Minify and compress** CSS and JS files in production
2. **Use CDN** for static assets
3. **Implement caching** for API responses
4. **Lazy load** components when possible
5. **Optimize images** if you add any

## Next Steps

- Customize the UI to match your brand
- Add authentication
- Implement error handling
- Add loading states
- Add analytics tracking
- Test thoroughly before deployment

## Support

For issues or questions:
- Check the main documentation: `../../docs/`
- Review API reference: `../../docs/API_REFERENCE.md`
- Check troubleshooting guide: `../../docs/TROUBLESHOOTING.md`

## License

This example is part of the subscription payment gateway system.
