/**
 * Customer Service
 * Handles customer creation, retrieval, and management
 */

const Stripe = require('stripe');
const { logger } = require('../middleware/logger');

const stripe = process.env.STRIPE_SECRET_KEY
  ? new Stripe(process.env.STRIPE_SECRET_KEY)
  : null;

/**
 * Create a new customer
 * @param {Object} customerData - Customer information
 * @param {string} customerData.email - Customer email
 * @param {string} customerData.name - Customer name
 * @param {string} customerData.orgId - Organization ID
 * @param {Object} customerData.metadata - Additional metadata
 * @returns {Promise<Object>} Stripe customer object
 */
const createCustomer = async ({ email, name, orgId, metadata = {} }) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!email || !orgId) {
    throw new Error('email and orgId are required.');
  }

  try {
    const customer = await stripe.customers.create({
      email,
      name,
      metadata: {
        orgId,
        ...metadata,
        createdAt: new Date().toISOString()
      }
    });

    logger.info({ 
      customerId: customer.id, 
      email, 
      orgId 
    }, 'Customer created successfully');

    return customer;
  } catch (error) {
    logger.error({ error, email, orgId }, 'Failed to create customer');
    throw error;
  }
};

/**
 * Get customer by ID
 * @param {string} customerId - Stripe customer ID
 * @returns {Promise<Object>} Stripe customer object
 */
const getCustomer = async (customerId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!customerId) {
    throw new Error('customerId is required.');
  }

  try {
    const customer = await stripe.customers.retrieve(customerId);
    logger.info({ customerId }, 'Customer retrieved successfully');
    return customer;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to retrieve customer');
    throw error;
  }
};

/**
 * Find customer by organization ID
 * @param {string} orgId - Organization ID
 * @returns {Promise<Object|null>} Stripe customer object or null if not found
 */
const findCustomerByOrgId = async (orgId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!orgId) {
    throw new Error('orgId is required.');
  }

  try {
    const customers = await stripe.customers.list({
      limit: 100,
      expand: ['data.subscriptions']
    });

    const customer = customers.data.find(c => c.metadata?.orgId === orgId);

    if (customer) {
      logger.info({ customerId: customer.id, orgId }, 'Customer found by orgId');
    } else {
      logger.info({ orgId }, 'No customer found for orgId');
    }

    return customer || null;
  } catch (error) {
    logger.error({ error, orgId }, 'Failed to find customer by orgId');
    throw error;
  }
};

/**
 * Update customer information
 * @param {string} customerId - Stripe customer ID
 * @param {Object} updateData - Data to update
 * @returns {Promise<Object>} Updated customer object
 */
const updateCustomer = async (customerId, updateData) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!customerId) {
    throw new Error('customerId is required.');
  }

  try {
    const customer = await stripe.customers.update(customerId, updateData);
    logger.info({ customerId }, 'Customer updated successfully');
    return customer;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to update customer');
    throw error;
  }
};

/**
 * Delete customer
 * @param {string} customerId - Stripe customer ID
 * @returns {Promise<Object>} Deleted customer object
 */
const deleteCustomer = async (customerId) => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }

  if (!customerId) {
    throw new Error('customerId is required.');
  }

  try {
    const customer = await stripe.customers.del(customerId);
    logger.info({ customerId }, 'Customer deleted successfully');
    return customer;
  } catch (error) {
    logger.error({ error, customerId }, 'Failed to delete customer');
    throw error;
  }
};

/**
 * Get or create customer for an organization
 * @param {Object} customerData - Customer information
 * @param {string} customerData.email - Customer email
 * @param {string} customerData.name - Customer name
 * @param {string} customerData.orgId - Organization ID
 * @returns {Promise<Object>} Stripe customer object
 */
const getOrCreateCustomer = async ({ email, name, orgId }) => {
  // First try to find existing customer
  const existingCustomer = await findCustomerByOrgId(orgId);

  if (existingCustomer) {
    logger.info({ customerId: existingCustomer.id, orgId }, 'Using existing customer');
    return existingCustomer;
  }

  // Create new customer if not found
  return createCustomer({ email, name, orgId });
};

module.exports = {
  createCustomer,
  getCustomer,
  findCustomerByOrgId,
  updateCustomer,
  deleteCustomer,
  getOrCreateCustomer
};
