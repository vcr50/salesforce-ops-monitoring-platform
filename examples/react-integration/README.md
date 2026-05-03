# React Integration Example

This example demonstrates how to integrate the subscription payment gateway system with a React application.

## Features

- Display pricing plans with checkout functionality
- Manage existing subscriptions
- Change subscription plans
- Cancel subscriptions
- Access customer portal
- Beautiful, responsive UI

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- React development environment

## Installation

1. Navigate to the example directory:

```bash
cd examples/react-integration
```

2. Install dependencies:

```bash
npm install
```

3. Set up environment variables:

Create a `.env` file in the root directory:

```env
REACT_APP_API_BASE_URL=https://your-api.com/api
REACT_APP_STRIPE_PUBLISHABLE_KEY=pk_test_your_key
```

## Project Structure

```
src/
├── components/
│   ├── PricingPlans.jsx          # Pricing plans display component
│   ├── PricingPlans.css          # Styles for pricing plans
│   ├── SubscriptionManagement.jsx  # Subscription management component
│   └── SubscriptionManagement.css  # Styles for subscription management
├── services/
│   └── billing.js                # Billing API service
└── App.jsx                       # Main application component
```

## Usage

### Display Pricing Plans

```jsx
import PricingPlans from './components/PricingPlans';

function App() {
  return (
    <PricingPlans 
      orgId="your-org-id"
      email="user@example.com"
      name="John Doe"
    />
  );
}
```

### Manage Subscriptions

```jsx
import SubscriptionManagement from './components/SubscriptionManagement';

function App() {
  return (
    <SubscriptionManagement 
      customerId="cus_123"
      orgId="org_123"
    />
  );
}
```

## Components

### PricingPlans

Displays available subscription plans with checkout functionality.

**Props:**
- `orgId` (string, required) - Organization ID
- `email` (string, required) - User email
- `name` (string, optional) - User name

**Features:**
- Responsive grid layout
- Highlighted popular plan
- Loading and error states
- Direct checkout integration

### SubscriptionManagement

Manages existing subscriptions with plan changes and cancellation.

**Props:**
- `customerId` (string, required) - Stripe customer ID
- `orgId` (string, required) - Organization ID

**Features:**
- Display current subscription details
- Change subscription plans
- Cancel subscriptions (immediate or at period end)
- Access customer portal
- Loading and error states

## API Service

The `billing.js` service provides methods for all billing operations:

```javascript
import { billingService } from './services/billing';

// Create checkout session
const { url } = await billingService.createCheckoutSession({
  orgId: 'org_123',
  email: 'user@example.com',
  plan: 'Professional'
});

// Get subscription
const { data } = await billingService.getSubscription('sub_123');

// Cancel subscription
await billingService.cancelSubscription('sub_123', false);

// Change plan
await billingService.changePlan('sub_123', 'price_new_plan_id');
```

## Customization

### Styling

All components use CSS modules for easy customization. Modify the CSS files to match your brand:

- `PricingPlans.css` - Pricing plans styles
- `SubscriptionManagement.css` - Subscription management styles

### Theme Colors

Update color variables in the CSS files to match your brand:

```css
:root {
  --primary-color: #3b82f6;
  --secondary-color: #6b7280;
  --success-color: #10b981;
  --danger-color: #ef4444;
}
```

## Development

Start the development server:

```bash
npm start
```

The application will open at `http://localhost:3000`

## Building for Production

Create an optimized production build:

```bash
npm run build
```

The build artifacts will be stored in the `build/` directory.

## Testing

Run tests:

```bash
npm test
```

## Common Use Cases

### 1. New User Onboarding

```jsx
function Onboarding() {
  const [step, setStep] = useState(1);

  return (
    <div>
      {step === 1 && <AccountSetup onNext={() => setStep(2)} />}
      {step === 2 && (
        <PricingPlans 
          orgId={user.orgId}
          email={user.email}
          name={user.name}
        />
      )}
    </div>
  );
}
```

### 2. Dashboard Integration

```jsx
function Dashboard() {
  return (
    <div>
      <Header />
      <main>
        <SubscriptionManagement 
          customerId={user.customerId}
          orgId={user.orgId}
        />
      </main>
    </div>
  );
}
```

### 3. Upgrade Flow

```jsx
function UpgradeFlow() {
  const [showPricing, setShowPricing] = useState(false);

  return (
    <div>
      <button onClick={() => setShowPricing(true)}>
        Upgrade Plan
      </button>

      {showPricing && (
        <PricingPlans 
          orgId={user.orgId}
          email={user.email}
          name={user.name}
        />
      )}
    </div>
  );
}
```

## Error Handling

All components include built-in error handling and display user-friendly error messages. You can customize error handling by modifying the error state in each component.

## Accessibility

The components follow WCAG 2.1 guidelines:
- Semantic HTML
- Keyboard navigation support
- ARIA labels where needed
- Focus management in dialogs

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Troubleshooting

### Checkout Not Working

1. Verify API base URL is correct
2. Check Stripe publishable key
3. Ensure orgId and email are provided
4. Check browser console for errors

### Subscription Not Loading

1. Verify customer ID is correct
2. Check API endpoint is accessible
3. Review server logs for errors
4. Ensure user has active subscription

### Styles Not Loading

1. Verify CSS files are imported correctly
2. Check for CSS syntax errors
3. Clear browser cache
4. Restart development server

## Support

For issues or questions:
- Check the main documentation: `../../docs/`
- Review API reference: `../../docs/API_REFERENCE.md`
- Check troubleshooting guide: `../../docs/TROUBLESHOOTING.md`

## License

This example is part of the subscription payment gateway system.
