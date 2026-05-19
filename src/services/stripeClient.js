
/**
 * Stripe Client Factory
 * Single source of truth for Stripe SDK instantiation.
 * All modules that need Stripe should import from here,
 * making it easy to mock in tests (jest.mock one file).
 */

const Stripe = require('stripe');

let _instance = null;

const getStripe = () => {
  if (!_instance) {
    if (!process.env.STRIPE_SECRET_KEY) {
      throw new Error('STRIPE_SECRET_KEY is required.');
    }
    _instance = new Stripe(process.env.STRIPE_SECRET_KEY);
  }
  return _instance;
};

/**
 * Reset the cached instance (useful in tests when env vars change)
 */
const resetStripeInstance = () => {
  _instance = null;
};

module.exports = { getStripe, resetStripeInstance };
