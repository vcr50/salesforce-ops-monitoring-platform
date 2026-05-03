const crypto = require('crypto');
const axios = require('axios');
const { logger } = require('../middleware/logger');

const ACTIVE_STATUSES = new Set(['active', 'trialing']);
const PAST_DUE_STATUSES = new Set(['past_due', 'unpaid', 'incomplete', 'incomplete_expired']);
const RAZORPAY_ACTIVE_STATUSES = new Set(['active', 'authenticated']);
const RAZORPAY_PAST_DUE_STATUSES = new Set(['pending', 'halted']);

const toSalesforceDate = (unixSeconds) => {
  if (!unixSeconds) {
    return null;
  }
  return new Date(unixSeconds * 1000).toISOString().slice(0, 10);
};

const mapStripeStatus = (stripeStatus) => {
  if (ACTIVE_STATUSES.has(stripeStatus)) {
    return 'Active';
  }
  if (PAST_DUE_STATUSES.has(stripeStatus)) {
    return 'Past Due';
  }
  if (stripeStatus === 'canceled') {
    return 'Canceled';
  }
  return 'Expired';
};

const getBillingEmailFromOrgId = (orgId) => {
  if (!orgId?.startsWith('web-lead:')) {
    return null;
  }

  const email = orgId.slice('web-lead:'.length).trim();
  return email.includes('@') ? email : null;
};

const normalizeOrgIdForSalesforce = (orgId) => {
  const billingEmail = getBillingEmailFromOrgId(orgId);
  if (!billingEmail) {
    return orgId;
  }

  return `WL${crypto.createHash('sha256').update(billingEmail.toLowerCase()).digest('hex').slice(0, 16)}`;
};

const mapRazorpayStatus = (razorpayStatus) => {
  if (RAZORPAY_ACTIVE_STATUSES.has(razorpayStatus)) {
    return 'Active';
  }
  if (RAZORPAY_PAST_DUE_STATUSES.has(razorpayStatus)) {
    return 'Past Due';
  }
  if (razorpayStatus === 'cancelled') {
    return 'Canceled';
  }
  return 'Expired';
};

const getSalesforceConfig = () => {
  const instanceUrl = process.env.SALESFORCE_INSTANCE_URL;
  const accessToken = process.env.SALESFORCE_ACCESS_TOKEN;

  if (!instanceUrl || !accessToken) {
    throw new Error('SALESFORCE_INSTANCE_URL and SALESFORCE_ACCESS_TOKEN are required for subscription sync.');
  }

  return {
    instanceUrl: instanceUrl.replace(/\/$/, ''),
    accessToken
  };
};

const syncSubscriptionToSalesforce = async ({
  orgId,
  plan = 'Professional',
  status = 'Active',
  expiryDate = null,
  stripeCustomerId = null,
  stripeSubscriptionId = null,
  eventName = null,
  billingEmail = null
}) => {
  if (!orgId) {
    throw new Error('orgId is required to sync a subscription.');
  }

  const { instanceUrl, accessToken } = getSalesforceConfig();
  const payload = {
    orgId: normalizeOrgIdForSalesforce(orgId),
    plan,
    status,
    expiryDate,
    stripeCustomerId,
    stripeSubscriptionId,
    eventName,
    billingEmail: billingEmail || getBillingEmailFromOrgId(orgId)
  };

  const response = await axios.post(
    `${instanceUrl}/services/apexrest/subscription/update`,
    payload,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      timeout: 15000
    }
  );

  logger.info({ orgId, status, eventName }, 'Subscription synced to Salesforce');
  return response.data;
};

const mapSubscriptionForSalesforce = (stripeSubscription, eventName) => ({
  orgId: stripeSubscription?.metadata?.orgId,
  plan: stripeSubscription?.metadata?.plan || 'Professional',
  status: mapStripeStatus(stripeSubscription?.status),
  expiryDate: toSalesforceDate(stripeSubscription?.current_period_end),
  stripeCustomerId: stripeSubscription?.customer,
  stripeSubscriptionId: stripeSubscription?.id,
  eventName,
  billingEmail: stripeSubscription?.metadata?.email || getBillingEmailFromOrgId(stripeSubscription?.metadata?.orgId)
});

const getRazorpaySubscriptionExpiry = (razorpaySubscription) => (
  razorpaySubscription?.current_end
  || razorpaySubscription?.end_at
  || razorpaySubscription?.charge_at
  || null
);

const mapRazorpaySubscriptionForSalesforce = (
  razorpaySubscription,
  eventName,
  statusOverride = null
) => ({
  orgId: razorpaySubscription?.notes?.orgId,
  plan: razorpaySubscription?.notes?.plan || 'Professional',
  status: statusOverride || mapRazorpayStatus(razorpaySubscription?.status),
  expiryDate: toSalesforceDate(getRazorpaySubscriptionExpiry(razorpaySubscription)),
  stripeCustomerId: razorpaySubscription?.customer_id,
  stripeSubscriptionId: razorpaySubscription?.id,
  eventName,
  billingEmail: razorpaySubscription?.notes?.email || getBillingEmailFromOrgId(razorpaySubscription?.notes?.orgId)
});

module.exports = {
  mapStripeStatus,
  mapSubscriptionForSalesforce,
  mapRazorpayStatus,
  mapRazorpaySubscriptionForSalesforce,
  getBillingEmailFromOrgId,
  normalizeOrgIdForSalesforce,
  syncSubscriptionToSalesforce
};
