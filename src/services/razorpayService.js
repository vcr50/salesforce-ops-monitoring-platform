const crypto = require('crypto');
const axios = require('axios');
const { logger } = require('../middleware/logger');

const RAZORPAY_API_BASE_URL = 'https://api.razorpay.com/v1';

const getRazorpayConfig = () => {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!keyId || !keySecret) {
    throw new Error('RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required.');
  }

  return { keyId, keySecret };
};

const getRazorpayClient = () => {
  const { keyId, keySecret } = getRazorpayConfig();
  return axios.create({
    baseURL: RAZORPAY_API_BASE_URL,
    auth: {
      username: keyId,
      password: keySecret
    },
    timeout: 15000
  });
};

const verifyWebhookSignature = (rawBody, signature, secret = process.env.RAZORPAY_WEBHOOK_SECRET) => {
  if (!secret) {
    throw new Error('RAZORPAY_WEBHOOK_SECRET is required.');
  }

  if (!signature) {
    return false;
  }

  const expected = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');

  const expectedBuffer = Buffer.from(expected, 'hex');
  const actualBuffer = Buffer.from(signature, 'hex');

  return expectedBuffer.length === actualBuffer.length
    && crypto.timingSafeEqual(expectedBuffer, actualBuffer);
};

const createOrReuseCustomer = async ({ email, name, orgId }) => {
  if (!email || !orgId) {
    throw new Error('email and orgId are required.');
  }

  const client = getRazorpayClient();
  const response = await client.post('/customers', {
    email,
    name,
    fail_existing: 0,
    notes: {
      orgId
    }
  });

  logger.info({ customerId: response.data.id, orgId }, 'Razorpay customer resolved');
  return response.data;
};

const createSubscription = async ({ orgId, email, plan, totalCount = 120 }) => {
  const planId = process.env.RAZORPAY_PROFESSIONAL_PLAN_ID;

  if (!planId) {
    throw new Error('RAZORPAY_PROFESSIONAL_PLAN_ID is required.');
  }

  const client = getRazorpayClient();
  const response = await client.post('/subscriptions', {
    plan_id: planId,
    total_count: totalCount,
    quantity: 1,
    customer_notify: true,
    notify_info: {
      notify_email: email
    },
    notes: {
      orgId,
      plan,
      email
    }
  });

  logger.info({
    subscriptionId: response.data.id,
    orgId,
    plan
  }, 'Razorpay subscription created');

  return response.data;
};

const getSubscription = async (subscriptionId) => {
  if (!subscriptionId) {
    throw new Error('subscriptionId is required.');
  }

  const client = getRazorpayClient();
  const response = await client.get(`/subscriptions/${subscriptionId}`);
  return response.data;
};

const createCheckoutSubscription = async ({ orgId, email, plan }) => {
  const subscription = await createSubscription({
    orgId,
    email,
    plan
  });

  return {
    provider: 'razorpay',
    customerId: subscription.customer_id || null,
    subscriptionId: subscription.id,
    url: subscription.short_url,
    subscription
  };
};

module.exports = {
  verifyWebhookSignature,
  createOrReuseCustomer,
  createSubscription,
  getSubscription,
  createCheckoutSubscription
};
