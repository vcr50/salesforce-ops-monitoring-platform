/**
 * Customer Portal Service
 * Handles Stripe Customer Portal operations for subscription management
 */

const Stripe = require('stripe');
const { logger } = require('../middleware/logger');

const stripe = process.env.STRIPE_SECRET_KEY
  ? new Stripe(process.env.STRIPE_SECRET_KEY)
  : null;

/**
 * Create a customer portal session
 * @param {string} customerId - Stripe customer ID
 * @param {string} returnUrl - URL to redirect to after portal session
 * @returns {Promise<Object>} Portal session object with URL
 */
const createPortalSession = async (customerId, returnUrl) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!customerId) {
    throw new Error('customerId is required.');
  }

  try {
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl
    });

    logger.info({ customerId }, 'Customer portal session created');
    return session;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to create portal session');
    throw error;
  }
};

/**
 * Get customer subscription details
 * @param {string} customerId - Stripe customer ID
 * @returns {Promise<Object|null>} Subscription object or null if not found
 */
const getCustomerSubscription = async (customerId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const subscriptions = await stripe.subscriptions.list({
      customer: customerId,
      status: 'all',
      limit: 1
    });

    if (subscriptions.data.length === 0) {
      return null;
    }

    const subscription = subscriptions.data[0];
    logger.info({ customerId, subscriptionId: subscription.id }, 'Customer subscription retrieved');
    return subscription;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to retrieve customer subscription');
    throw error;
  }
};

/**
 * Get customer payment methods
 * @param {string} customerId - Stripe customer ID
 * @returns {Promise<Array>} Array of payment methods
 */
const getCustomerPaymentMethods = async (customerId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const paymentMethods = await stripe.paymentMethods.list({
      customer: customerId,
      type: 'card'
    });

    logger.info({ customerId, count: paymentMethods.data.length }, 'Customer payment methods retrieved');
    return paymentMethods.data;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to retrieve customer payment methods');
    throw error;
  }
};

/**
 * Get customer invoices
 * @param {string} customerId - Stripe customer ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Number of invoices to retrieve (default: 10)
 * @returns {Promise<Object>} Object with invoices array and has_more flag
 */
const getCustomerInvoices = async (customerId, options = {}) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const invoices = await stripe.invoices.list({
      customer: customerId,
      limit: options.limit || 10
    });

    logger.info({ customerId, count: invoices.data.length }, 'Customer invoices retrieved');
    return {
      invoices: invoices.data,
      has_more: invoices.has_more
    };
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to retrieve customer invoices');
    throw error;
  }
};

/**
 * Get upcoming invoice for customer
 * @param {string} customerId - Stripe customer ID
 * @param {string} subscriptionId - Stripe subscription ID (optional)
 * @returns {Promise<Object>} Upcoming invoice object
 */
const getUpcomingInvoice = async (customerId, subscriptionId = null) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const invoice = await stripe.invoices.retrieveUpcoming({
      customer: customerId,
      subscription: subscriptionId
    });

    logger.info({ customerId, subscriptionId }, 'Upcoming invoice retrieved');
    return invoice;
  } catch (error) {
    logger.error({ error, customerId, subscriptionId }, 'Failed to retrieve upcoming invoice');
    throw error;
  }
};

/**
 * Update customer default payment method
 * @param {string} customerId - Stripe customer ID
 * @param {string} paymentMethodId - Payment method ID to set as default
 * @returns {Promise<Object>} Updated customer object
 */
const updateDefaultPaymentMethod = async (customerId, paymentMethodId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const customer = await stripe.customers.update(customerId, {
      invoice_settings: {
        default_payment_method: paymentMethodId
      }
    });

    logger.info({ customerId, paymentMethodId }, 'Default payment method updated');
    return customer;
  } catch (error) {
    logger.error({ error, customerId, paymentMethodId }, 'Failed to update default payment method');
    throw error;
  }
};

/**
 * Attach payment method to customer
 * @param {string} customerId - Stripe customer ID
 * @param {string} paymentMethodId - Payment method ID to attach
 * @returns {Promise<Object>} Payment method object
 */
const attachPaymentMethod = async (customerId, paymentMethodId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const paymentMethod = await stripe.paymentMethods.attach(paymentMethodId, {
      customer: customerId
    });

    logger.info({ customerId, paymentMethodId }, 'Payment method attached');
    return paymentMethod;
  } catch (error) {
    logger.error({ error, customerId, paymentMethodId }, 'Failed to attach payment method');
    throw error;
  }
};

/**
 * Detach payment method from customer
 * @param {string} paymentMethodId - Payment method ID to detach
 * @returns {Promise<Object>} Payment method object
 */
const detachPaymentMethod = async (paymentMethodId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  try {
    const paymentMethod = await stripe.paymentMethods.detach(paymentMethodId);

    logger.info({ paymentMethodId }, 'Payment method detached');
    return paymentMethod;
  } catch (error) {
    logger.error({ error, paymentMethodId }, 'Failed to detach payment method');
    throw error;
  }
};

module.exports = {
  createPortalSession,
  getCustomerSubscription,
  getCustomerPaymentMethods,
  getCustomerInvoices,
  getUpcomingInvoice,
  updateDefaultPaymentMethod,
  attachPaymentMethod,
  detachPaymentMethod
};
