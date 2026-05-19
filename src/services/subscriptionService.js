/**
 * Subscription Service
 * Provides plan metadata and Stripe-backed subscription operations.
 * Razorpay checkout is handled through razorpayService because its hosted
 * subscription authorization flow is different from Stripe Billing.
 */

const { logger } = require('../middleware/logger');
const { getStripe } = require('../services/stripeClient');
const { config } = require('../config');

const getProfessionalAmount = () => config.billing.professionalMonthlyAmountInr;

const getPlans = () => [
  {
    id: 'starter',
    name: 'Starter',
    price: 0,
    currency: config.billing.currency,
    interval: 'month',
    features: ['5 integrations', 'Basic alerts', '7-day history', 'Email support']
  },
  {
    id: config.stripe.professionalPriceId || config.razorpay.professionalPlanId || 'professional',
    name: 'Professional',
    price: getProfessionalAmount(),
    currency: config.billing.currency,
    interval: 'month',
    features: ['25 integrations', 'Agentforce AI', 'Business impact', '30-day history', 'Priority support']
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: null,
    currency: config.billing.currency,
    interval: 'month',
    features: ['Unlimited integrations', 'Auto-heal', 'Custom runbooks', 'Unlimited history', 'Dedicated success manager']
  }
];

const normalizePlanName = (value) => String(value || '').trim().toLowerCase();

const getPlanByName = (name) => getPlans().find((plan) => normalizePlanName(plan.name) === normalizePlanName(name));

const getPlanById = (planId) => getPlans().find((plan) => plan.id === planId || normalizePlanName(plan.name) === normalizePlanName(planId));

const createSubscription = async ({ customerId, planId, metadata = {} }) => {
  const stripe = getStripe();
  const subscription = await stripe.subscriptions.create({
    customer: customerId,
    items: [{ price: planId }],
    metadata,
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent']
  });

  logger.info({ subscriptionId: subscription.id, customerId, planId }, 'Stripe subscription created');
  return subscription;
};

const getSubscription = async (subscriptionId) => getStripe().subscriptions.retrieve(subscriptionId);

const updateSubscription = async (subscriptionId, updateData) => getStripe().subscriptions.update(subscriptionId, updateData);

const cancelSubscription = async (subscriptionId, immediate = false) => {
  const stripe = getStripe();
  if (immediate) {
    return stripe.subscriptions.cancel(subscriptionId);
  }
  return stripe.subscriptions.update(subscriptionId, {
    cancel_at_period_end: true
  });
};

const changePlan = async (subscriptionId, newPlanId) => {
  const stripe = getStripe();
  const subscription = await stripe.subscriptions.retrieve(subscriptionId);
  const itemId = subscription.items?.data?.[0]?.id;

  if (!itemId) {
    throw new Error('Subscription item not found.');
  }

  return stripe.subscriptions.update(subscriptionId, {
    items: [{ id: itemId, price: newPlanId }],
    proration_behavior: 'create_prorations'
  });
};

const getUsageStats = async (subscriptionId) => ({
  subscriptionId,
  period: 'month',
  usage: {
    integrations: 0,
    incidents: 0,
    apiCalls: 0
  }
});

module.exports = {
  getPlans,
  getPlanByName,
  getPlanById,
  normalizePlanName,
  createSubscription,
  getSubscription,
  updateSubscription,
  cancelSubscription,
  changePlan,
  getUsageStats
};
