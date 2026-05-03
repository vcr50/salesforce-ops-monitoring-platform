/**
 * Subscription Controller
 * Handles HTTP requests for subscription management
 */

const subscriptionService = require('../services/subscriptionService');
const customerPortalService = require('../services/customerPortalService');
const { logger } = require('../middleware/logger');

/**
 * Get all available plans
 * @route GET /api/subscriptions/plans
 */
const getPlans = async (req, res, next) => {
  try {
    const plans = subscriptionService.getPlans();
    res.json({
      success: true,
      data: { plans }
    });
  } catch (error) {
    logger.error({ error }, 'Failed to get plans');
    next(error);
  }
};

/**
 * Get plan by ID
 * @route GET /api/subscriptions/plans/:planId
 */
const getPlanById = async (req, res, next) => {
  try {
    const { planId } = req.params;
    const plan = subscriptionService.getPlanById(planId);

    if (!plan) {
      return res.status(404).json({
        success: false,
        error: 'Plan not found'
      });
    }

    res.json({
      success: true,
      data: { plan }
    });
  } catch (error) {
    logger.error({ error, planId: req.params.planId }, 'Failed to get plan');
    next(error);
  }
};

/**
 * Create a new subscription
 * @route POST /api/subscriptions
 */
const createSubscription = async (req, res, next) => {
  try {
    const { customerId, planId, orgId, email } = req.body;

    if (!customerId || !planId) {
      return res.status(400).json({
        success: false,
        error: 'customerId and planId are required'
      });
    }

    const metadata = {
      orgId,
      email,
      createdAt: new Date().toISOString()
    };

    const subscription = await subscriptionService.createSubscription({
      customerId,
      planId,
      metadata
    });

    logger.info({ 
      subscriptionId: subscription.id,
      customerId,
      planId 
    }, 'Subscription created successfully');

    res.status(201).json({
      success: true,
      data: {
        subscriptionId: subscription.id,
        status: subscription.status,
        clientSecret: subscription.latest_invoice?.payment_intent?.client_secret
      }
    });
  } catch (error) {
    logger.error({ error, body: req.body }, 'Failed to create subscription');
    next(error);
  }
};

/**
 * Get subscription by ID
 * @route GET /api/subscriptions/:subscriptionId
 */
const getSubscription = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const subscription = await subscriptionService.getSubscription(subscriptionId);

    if (!subscription) {
      return res.status(404).json({
        success: false,
        error: 'Subscription not found'
      });
    }

    res.json({
      success: true,
      data: { subscription }
    });
  } catch (error) {
    logger.error({ error, subscriptionId: req.params.subscriptionId }, 'Failed to get subscription');
    next(error);
  }
};

/**
 * Update subscription
 * @route PATCH /api/subscriptions/:subscriptionId
 */
const updateSubscription = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const updateData = req.body;

    const subscription = await subscriptionService.updateSubscription(
      subscriptionId,
      updateData
    );

    logger.info({ subscriptionId }, 'Subscription updated successfully');

    res.json({
      success: true,
      data: { subscription }
    });
  } catch (error) {
    logger.error({ error, subscriptionId: req.params.subscriptionId }, 'Failed to update subscription');
    next(error);
  }
};

/**
 * Cancel subscription
 * @route POST /api/subscriptions/:subscriptionId/cancel
 */
const cancelSubscription = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const { immediate = false } = req.body;

    const subscription = await subscriptionService.cancelSubscription(
      subscriptionId,
      immediate
    );

    logger.info({ subscriptionId, immediate }, 'Subscription cancelled successfully');

    res.json({
      success: true,
      data: { subscription }
    });
  } catch (error) {
    logger.error({ error, subscriptionId: req.params.subscriptionId }, 'Failed to cancel subscription');
    next(error);
  }
};

/**
 * Change subscription plan
 * @route POST /api/subscriptions/:subscriptionId/change-plan
 */
const changePlan = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const { newPlanId } = req.body;

    if (!newPlanId) {
      return res.status(400).json({
        success: false,
        error: 'newPlanId is required'
      });
    }

    const subscription = await subscriptionService.changePlan(
      subscriptionId,
      newPlanId
    );

    logger.info({ subscriptionId, newPlanId }, 'Plan changed successfully');

    res.json({
      success: true,
      data: { subscription }
    });
  } catch (error) {
    logger.error({ error, subscriptionId: req.params.subscriptionId }, 'Failed to change plan');
    next(error);
  }
};

/**
 * Get subscription usage statistics
 * @route GET /api/subscriptions/:subscriptionId/usage
 */
const getUsageStats = async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const stats = await subscriptionService.getUsageStats(subscriptionId);

    res.json({
      success: true,
      data: { stats }
    });
  } catch (error) {
    logger.error({ error, subscriptionId: req.params.subscriptionId }, 'Failed to get usage stats');
    next(error);
  }
};

/**
 * Create customer portal session
 * @route POST /api/subscriptions/portal
 */
const createPortalSession = async (req, res, next) => {
  try {
    const { customerId, returnUrl } = req.body;

    if (!customerId) {
      return res.status(400).json({
        success: false,
        error: 'customerId is required'
      });
    }

    const baseUrl = process.env.BILLING_RETURN_BASE_URL || 
                    `${req.protocol}://${req.get('host')}`;
    const finalReturnUrl = returnUrl || `${baseUrl}/dashboard`;

    const session = await customerPortalService.createPortalSession(
      customerId,
      finalReturnUrl
    );

    logger.info({ customerId }, 'Portal session created successfully');

    res.json({
      success: true,
      data: { url: session.url }
    });
  } catch (error) {
    logger.error({ error, customerId: req.body.customerId }, 'Failed to create portal session');
    next(error);
  }
};

/**
 * Get customer subscription details
 * @route GET /api/subscriptions/customer/:customerId
 */
const getCustomerSubscription = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const subscription = await customerPortalService.getCustomerSubscription(customerId);

    if (!subscription) {
      return res.status(404).json({
        success: false,
        error: 'No subscription found for this customer'
      });
    }

    res.json({
      success: true,
      data: { subscription }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to get customer subscription');
    next(error);
  }
};

/**
 * Get customer payment methods
 * @route GET /api/subscriptions/customer/:customerId/payment-methods
 */
const getCustomerPaymentMethods = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const paymentMethods = await customerPortalService.getCustomerPaymentMethods(customerId);

    res.json({
      success: true,
      data: { paymentMethods }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to get payment methods');
    next(error);
  }
};

/**
 * Get customer invoices
 * @route GET /api/subscriptions/customer/:customerId/invoices
 */
const getCustomerInvoices = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const { limit } = req.query;

    const result = await customerPortalService.getCustomerInvoices(customerId, {
      limit: limit ? parseInt(limit, 10) : undefined
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to get invoices');
    next(error);
  }
};

/**
 * Get upcoming invoice
 * @route GET /api/subscriptions/customer/:customerId/upcoming-invoice
 */
const getUpcomingInvoice = async (req, res, next) => {
  try {
    const { customerId } = req.params;
    const { subscriptionId } = req.query;

    const invoice = await customerPortalService.getUpcomingInvoice(
      customerId,
      subscriptionId
    );

    res.json({
      success: true,
      data: { invoice }
    });
  } catch (error) {
    logger.error({ error, customerId: req.params.customerId }, 'Failed to get upcoming invoice');
    next(error);
  }
};

module.exports = {
  getPlans,
  getPlanById,
  createSubscription,
  getSubscription,
  updateSubscription,
  cancelSubscription,
  changePlan,
  getUsageStats,
  createPortalSession,
  getCustomerSubscription,
  getCustomerPaymentMethods,
  getCustomerInvoices,
  getUpcomingInvoice
};
