/**
 * Subscription Service
 * Provides plan metadata and Stripe-backed subscription operations.
 * Razorpay checkout is handled through razorpayService because its hosted
 * subscription authorization flow is different from Stripe Billing.
 */

const Stripe = require('stripe');
const { logger } = require('../middleware/logger');

const getStripe = () => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }
  return new Stripe(process.env.STRIPE_SECRET_KEY);
};

const getProfessionalAmount = () => Number(process.env.PROFESSIONAL_MONTHLY_AMOUNT_INR || 2499);

const getPlans = () => [
  {
    id: 'starter',
    name: 'Starter',
    price: 0,
    currency: process.env.BILLING_CURRENCY || 'INR',
    interval: 'month',
    features: ['5 integrations', 'Basic alerts', '7-day history', 'Email support']
  },
  {
    id: process.env.STRIPE_PROFESSIONAL_PRICE_ID || process.env.RAZORPAY_PROFESSIONAL_PLAN_ID || 'professional',
    name: 'Professional',
    price: getProfessionalAmount(),
    currency: process.env.BILLING_CURRENCY || 'INR',
    interval: 'month',
    features: ['25 integrations', 'Agentforce AI', 'Business impact', '30-day history', 'Priority support']
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price: null,
    currency: process.env.BILLING_CURRENCY || 'INR',
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
  createSubscription,
  getSubscription,
  updateSubscription,
  cancelSubscription,
  changePlan,
  getUsageStats
};
