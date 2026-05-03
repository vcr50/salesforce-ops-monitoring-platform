# Local Setup Guide for Payment Gateway

This guide will help you set up and run the SentinelFlow Payment Gateway system locally.

## Prerequisites

Before you begin, ensure you have:

- Node.js (v16.0.0 or higher) installed
- npm or yarn package manager
- A Stripe account (free account works for testing)
- Git (optional, for version control)

## Step 1: Install Dependencies

Navigate to the project directory and install the required packages:

```bash
cd "d:\TomCodeX Inc\SEOMP"
npm install
```

## Step 2: Configure Environment Variables

The `.env` file has been updated with the necessary Stripe configuration. You need to update the following values:

### Stripe Configuration

1. **Get your Stripe API keys:**
   - Log in to your Stripe dashboard
   - Go to Developers > API keys
   - Copy your test keys

2. **Update .env file:**
   ```env
   STRIPE_SECRET_KEY=sk_test_your_actual_secret_key
   STRIPE_PUBLISHABLE_KEY=pk_test_your_actual_publishable_key
   STRIPE_WEBHOOK_SECRET=whsec_your_actual_webhook_secret
   ```

### Stripe Price IDs

1. **Create products and prices in Stripe:**
   - Go to Products in your Stripe dashboard
   - Create three products: Starter, Professional, Enterprise
   - Add prices to each product

2. **Update .env file with price IDs:**
   ```env
   STRIPE_STARTER_PRICE_ID=price_actual_starter_price_id
   STRIPE_PROFESSIONAL_PRICE_ID=price_actual_professional_price_id
   STRIPE_ENTERPRISE_PRICE_ID=price_actual_enterprise_price_id
   ```

## Step 3: Set Up Webhooks (Optional for Testing)

For full functionality, you need to set up webhooks:

1. **Install Stripe CLI:**
   ```bash
   # Using npm
   npm install -g stripe-cli

   # Or download from https://stripe.com/docs/stripe-cli
   ```

2. **Login to Stripe:**
   ```bash
   stripe login
   ```

3. **Forward webhooks to your local server:**
   ```bash
   stripe listen --forward-to localhost:3000/api/billing/webhook
   ```

4. **Copy the webhook signing secret** and update your .env file:
   ```env
   STRIPE_WEBHOOK_SECRET=whsec_actual_webhook_secret
   ```

## Step 4: Start the Server

### Development Mode (with auto-restart)

```bash
npm run dev
```

### Production Mode

```bash
npm start
```

The server will start on port 3000 (or the port specified in your .env file).

## Step 5: Test the Application

### Test the API Endpoints

1. **Health Check:**
   ```bash
   curl http://localhost:3000/health
   ```

2. **Get Plans:**
   ```bash
   curl http://localhost:3000/api/subscriptions/plans
   ```

### Test the Frontend Examples

#### Option 1: Vanilla JS Example

1. Navigate to the vanilla-js example:
   ```bash
   cd examples/vanilla-js
   ```

2. Start a local server:
   ```bash
   # Using Python
   python -m http.server 8000

   # Or using Node.js
   npx http-server -p 8000
   ```

3. Open your browser to: `http://localhost:8000`

#### Option 2: React Example

1. Navigate to the react-integration example:
   ```bash
   cd examples/react-integration
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```

4. Open your browser to the URL shown in the terminal (usually `http://localhost:5173`)

## Step 6: Test Payment Flow

### Using Test Cards

Stripe provides test card numbers for testing:

- **Success:** 4242 4242 4242 4242
- **Requires 3D Secure:** 4000 0025 0000 3155
- **Declined:** 4000 0000 0000 0002
- **Insufficient Funds:** 4000 0000 0000 9995

Use any future expiration date and any CVC.

### Test the Complete Flow

1. Open the frontend example in your browser
2. Select a pricing plan
3. Click "Choose [Plan Name]"
4. Enter test card details
5. Complete the checkout
6. Verify the subscription was created

## Common Issues and Solutions

### Issue: Server won't start

**Solution:**
- Check if port 3000 is already in use
- Verify all dependencies are installed
- Check the .env file for correct configuration

### Issue: Stripe API errors

**Solution:**
- Verify your Stripe keys are correct
- Ensure you're using test keys for development
- Check your Stripe dashboard for any errors

### Issue: Webhooks not working

**Solution:**
- Ensure Stripe CLI is running
- Verify the webhook URL is correct
- Check the webhook signing secret

### Issue: Frontend can't connect to API

**Solution:**
- Verify the API base URL in the frontend code
- Check CORS configuration in .env
- Ensure the server is running

## Next Steps

After successful local setup:

1. **Customize the UI** to match your brand
2. **Implement authentication** for protected endpoints
3. **Add error handling** for production
4. **Set up monitoring** and logging
5. **Test thoroughly** before deployment
6. **Configure production environment** variables
7. **Deploy to your hosting platform**

## Additional Resources

- [Stripe Documentation](https://stripe.com/docs)
- [Stripe CLI Guide](https://stripe.com/docs/stripe-cli)
- [API Reference](./API_REFERENCE.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

## Support

If you encounter issues:

1. Check the [Troubleshooting Guide](./TROUBLESHOOTING.md)
2. Review the [API Reference](./API_REFERENCE.md)
3. Check Stripe dashboard for errors
4. Review server logs for detailed error messages

## Security Notes

⚠️ **Important:**

- Never commit your .env file to version control
- Use environment variables for all sensitive data
- Never expose secret keys in client-side code
- Always use HTTPS in production
- Implement proper authentication and authorization
- Regularly update dependencies for security patches
