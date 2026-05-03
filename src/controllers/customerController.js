/**
 * Customer Controller
 * Handles HTTP requests for customer management
 */

const customerService = require('../services/customerService');
const { logger } = require('../middleware/logger');

/**
 * Create a new customer
 * @route POST /api/customers
 */
const createCustomer = async (req, res, next) => {
  try {
    const { email, name, orgId, metadata } = req.body;

    if (!email || !orgId) {
      return res.status(400).json({
        success: false,
        error: 'email and orgId are required'
      });
    }

    const customer = await customerService.createCustomer({
      email,
      name,
      orgId,
      metadata
    });

    logger.info({ 
      customerId: customer.id, 
      email, 
      orgId 
    }, 'Customer created successfully');

    res.status(201).json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, body: req.body }, 'Failed to create customer');
    next(error);
  }
};

/**
 * Get customer by ID
 * @route GET /api/customers/:customerId
 */
const getCustomer = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const customer = await customerService.getCustomer(customerId);

    if (!customer) {
      return res.status(404).json({
        success: false,
        error: 'Customer not found'
      });
    }

    res.json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to get customer');
    next(error);
  }
};

/**
 * Find customer by organization ID
 * @route GET /api/customers/org/:orgId
 */
const findCustomerByOrgId = async (req, res, next) => {
  try {
    const { orgId } = req.params;
    const customer = await customerService.findCustomerByOrgId(orgId);

    if (!customer) {
      return res.status(404).json({
        success: false,
        error: 'Customer not found for this organization'
      });
    }

    res.json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, orgId: req.params.orgId }, 'Failed to find customer by orgId');
    next(error);
  }
};

/**
 * Update customer information
 * @route PATCH /api/customers/:customerId
 */
const updateCustomer = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const updateData = req.body;

    const customer = await customerService.updateCustomer(customerId, updateData);

    logger.info({ customerId }, 'Customer updated successfully');

    res.json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to update customer');
    next(error);
  }
};

/**
 * Delete customer
 * @route DELETE /api/customers/:customerId
 */
const deleteCustomer = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const customer = await customerService.deleteCustomer(customerId);

    logger.info({ customerId }, 'Customer deleted successfully');

    res.json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to delete customer');
    next(error);
  }
};

/**
 * Get or create customer for an organization
 * @route POST /api/customers/get-or-create
 */
const getOrCreateCustomer = async (req, res, next) => {
  try {
    const { email, name, orgId } = req.body;

    if (!email || !orgId) {
      return res.status(400).json({
        success: false,
        error: 'email and orgId are required'
      });
    }

    const customer = await customerService.getOrCreateCustomer({
      email,
      name,
      orgId
    });

    logger.info({ 
      customerId: customer.id, 
      email, 
      orgId 
    }, 'Customer retrieved or created successfully');

    res.json({
      success: true,
      data: { customer }
    });
  } catch (error) {
    logger.error({ error, body: req.body }, 'Failed to get or create customer');
    next(error);
  }
};

module.exports = {
  createCustomer,
  getCustomer,
  findCustomerByOrgId,
  updateCustomer,
  deleteCustomer,
  getOrCreateCustomer
};
