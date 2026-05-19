
/**
 * Centralized Configuration
 * Reads and validates all required environment variables at startup.
 * Services should import config, not process.env directly.
 */

const required = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Environment variable ${name} is required but not set.`);
  }
  return value;
};

const optional = (name, defaultValue = null) => process.env[name] || defaultValue;

const config = Object.freeze({
  env: optional('NODE_ENV', 'development'),
  port: parseInt(optional('PORT', '3000'), 10),
  logLevel: optional('LOG_LEVEL', 'info'),

  // Session
  sessionSecret: optional('SESSION_SECRET', 'your-secret-key'),

  // CORS
  allowedOrigins: optional('ALLOWED_ORIGINS', '*'),

  // Salesforce
  salesforce: {
    instanceUrl: optional('SALESFORCE_INSTANCE_URL'),
    accessToken: optional('SALESFORCE_ACCESS_TOKEN'),
  },

  // Stripe
  stripe: {
    secretKey: optional('STRIPE_SECRET_KEY'),
    webhookSecret: optional('STRIPE_WEBHOOK_SECRET'),
    professionalPriceId: optional('STRIPE_PROFESSIONAL_PRICE_ID'),
  },

  // Razorpay
  razorpay: {
    keyId: optional('RAZORPAY_KEY_ID'),
    keySecret: optional('RAZORPAY_KEY_SECRET'),
    webhookSecret: optional('RAZORPAY_WEBHOOK_SECRET'),
    professionalPlanId: optional('RAZORPAY_PROFESSIONAL_PLAN_ID'),
  },

  // Billing
  billing: {
    provider: optional('BILLING_PROVIDER', 'stripe'),
    currency: optional('BILLING_CURRENCY', 'INR'),
    returnBaseUrl: optional('BILLING_RETURN_BASE_URL'),
    professionalMonthlyAmountInr: Number(optional('PROFESSIONAL_MONTHLY_AMOUNT_INR', '2499')),
  },

  // OAuth
  oauth: {
    clientId: optional('SF_CLIENT_ID') || optional('SALESFORCE_CLIENT_ID'),
    clientSecret: optional('SF_CLIENT_SECRET') || optional('SALESFORCE_CLIENT_SECRET'),
    callbackUrl: optional('SALESFORCE_CALLBACK_URL'),
  },
});

/**
 * Validate that all config needed for a given feature is present.
 * Call this at startup or before first use — fails fast with a clear message.
 */
const validateSection = (section) => {
  if (!config[section]) {
    throw new Error(`Unknown config section: ${section}`);
  }
  const missing = Object.entries(config[section])
    .filter(([, value]) => value === null || value === undefined || value === '')
    .map(([key]) => key);
  if (missing.length > 0) {
    throw new Error(`Missing config for ${section}: ${missing.join(', ')}`);
  }
  return true;
};

module.exports = { config, required, optional, validateSection };
