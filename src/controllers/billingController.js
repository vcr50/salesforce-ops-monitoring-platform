const Stripe = require('stripe');
const { logger } = require('../middleware/logger');
const customerService = require('../services/customerService');
const subscriptionService = require('../services/subscriptionService');
const razorpayService = require('../services/razorpayService');
const { getBillingProvider } = require('../services/billingProviderService');
const {
  mapSubscriptionForSalesforce,
  mapRazorpaySubscriptionForSalesforce,
  syncSubscriptionToSalesforce
} = require('../services/subscriptionSyncService');

const stripe = process.env.STRIPE_SECRET_KEY
  ? new Stripe(process.env.STRIPE_SECRET_KEY)
  : null;

const getStripe = () => {
  if (!stripe) {
    throw new Error('STRIPE_SECRET_KEY is required.');
  }
  return stripe;
};

const createCheckoutSession = async (req, res, next) => {
  try {
    const { orgId, email, name, plan = 'Professional' } = req.body;
    const provider = getBillingProvider();

    if (!orgId) {
      return res.status(400).json({ error: 'orgId is required.' });
    }

    if (provider === 'razorpay' && !email) {
      return res.status(400).json({ error: 'email is required.' });
    }

    // Get plan details
    const planDetails = subscriptionService.getPlanByName(plan);
    if (!planDetails) {
      return res.status(400).json({ error: `Invalid plan: ${plan}` });
    }

    if (planDetails.name === 'Starter') {
      return res.status(400).json({ error: 'Starter is a free plan and does not require checkout.' });
    }

    if (planDetails.name === 'Enterprise') {
      return res.status(400).json({ error: 'Enterprise checkout is handled by sales.' });
    }

    if (provider === 'razorpay') {
      const checkout = await razorpayService.createCheckoutSubscription({
        orgId,
        email,
        name,
        plan: planDetails.name
      });

      if (!checkout.url) {
        throw new Error('Razorpay subscription did not return a checkout URL.');
      }

      return res.status(200).json({
        provider,
        customerId: checkout.customerId,
        subscriptionId: checkout.subscriptionId,
        url: checkout.url
      });
    }

    if (!email) {
      return res.status(400).json({ error: 'email is required.' });
    }

    // Stripe checkout uses Stripe Customer objects. Razorpay customer creation
    // happens in razorpayService because it uses Razorpay's API and ids.
    const customer = await customerService.getOrCreateCustomer({
      email,
      name,
      orgId
    });

    const priceId = planDetails.name === 'Professional'
      ? process.env.STRIPE_PROFESSIONAL_PRICE_ID
      : planDetails.id;
    if (!priceId) {
      return res.status(500).json({ error: 'Plan price ID is not configured.' });
    }

    const baseUrl = process.env.BILLING_RETURN_BASE_URL || `${req.protocol}://${req.get('host')}`;

    const session = await getStripe().checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      customer: customer.id,
      client_reference_id: orgId,
      line_items: [{ price: priceId, quantity: 1 }],
      subscription_data: {
        metadata: {
          orgId,
          plan,
          email
        }
      },
      metadata: {
        orgId,
        plan,
        email
      },
      success_url: `${baseUrl}/upgrade.html?checkout=success&orgId=${encodeURIComponent(orgId)}&plan=${encodeURIComponent(plan)}`,
      cancel_url: `${baseUrl}/upgrade.html?checkout=cancelled&orgId=${encodeURIComponent(orgId)}&plan=${encodeURIComponent(plan)}`
    });

    logger.info({ 
      sessionId: session.id, 
      customerId: customer.id,
      orgId,
      plan 
    }, 'Checkout session created');

    return res.status(200).json({ 
      provider,
      sessionId: session.id, 
      url: session.url 
    });
  } catch (error) {
    logger.error({ error, body: req.body }, 'Failed to create checkout session');
    return next(error);
  }
};

const resolveCheckoutSession = async (session) => {
  if (!session.subscription) {
    return {
      orgId: session.client_reference_id || session.metadata?.orgId,
      plan: session.metadata?.plan || 'Professional',
      status: 'Active',
      stripeCustomerId: session.customer,
      stripeSubscriptionId: null,
      eventName: 'checkout.session.completed'
    };
  }

  const subscription = await getStripe().subscriptions.retrieve(session.subscription);
  return mapSubscriptionForSalesforce(subscription, 'checkout.session.completed');
};

const handleWebhook = async (req, res, next) => {
  try {
    const provider = getBillingProvider();
    if (provider === 'razorpay') {
      return handleRazorpayWebhook(req, res, next);
    }

    const signature = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    const event = webhookSecret
      ? getStripe().webhooks.constructEvent(req.body, signature, webhookSecret)
      : JSON.parse(req.body.toString('utf8'));

    logger.info({ eventType: event.type }, 'Processing Stripe webhook');

    let syncPayload = null;

    if (event.type === 'checkout.session.completed') {
      syncPayload = await resolveCheckoutSession(event.data.object);
    }

    if (['invoice.paid', 'invoice.payment_failed'].includes(event.type)) {
      const invoice = event.data.object;
      if (invoice.subscription) {
        const subscription = await getStripe().subscriptions.retrieve(invoice.subscription);
        syncPayload = mapSubscriptionForSalesforce(subscription, event.type);
        if (event.type === 'invoice.payment_failed') {
          syncPayload.status = 'Past Due';
        }
      }
    }

    if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
      syncPayload = mapSubscriptionForSalesforce(event.data.object, event.type);
    }

    if (syncPayload?.orgId) {
      await syncSubscriptionToSalesforce(syncPayload);
      logger.info({ 
        orgId: syncPayload.orgId,
        status: syncPayload.status,
        eventType: event.type 
      }, 'Subscription synced to Salesforce');
    } else {
      logger.info({ eventType: event.type }, 'Stripe event acknowledged without subscription sync');
    }

    return res.json({ received: true });
  } catch (error) {
    logger.error({ error }, 'Failed to handle webhook');
    return next(error);
  }
};

const processedRazorpayEvents = new Set();

const getRazorpayEventId = (event) => {
  const subscriptionId = event?.payload?.subscription?.entity?.id;
  const paymentId = event?.payload?.payment?.entity?.id;
  return event?.id || [event?.event, subscriptionId, paymentId].filter(Boolean).join(':');
};

const resolveRazorpaySyncPayload = async (event) => {
  const eventName = event.event;
  let subscription = event?.payload?.subscription?.entity;
  const payment = event?.payload?.payment?.entity;

  if (!subscription && eventName === 'payment.failed' && payment?.subscription_id) {
    subscription = await razorpayService.getSubscription(payment.subscription_id);
  }

  if (!subscription) {
    return null;
  }

  if (eventName === 'payment.failed') {
    return mapRazorpaySubscriptionForSalesforce(subscription, eventName, 'Past Due');
  }

  if (eventName === 'subscription.cancelled') {
    return mapRazorpaySubscriptionForSalesforce(subscription, eventName, 'Canceled');
  }

  if (eventName === 'subscription.completed' || eventName === 'subscription.expired') {
    return mapRazorpaySubscriptionForSalesforce(subscription, eventName, 'Expired');
  }

  if ([
    'subscription.activated',
    'subscription.authenticated',
    'subscription.charged',
    'subscription.pending',
    'subscription.halted'
  ].includes(eventName)) {
    return mapRazorpaySubscriptionForSalesforce(subscription, eventName);
  }

  return null;
};

const handleRazorpayWebhook = async (req, res, next) => {
  try {
    const rawBody = Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body || {}));
    const signature = req.headers['x-razorpay-signature'];

    if (!razorpayService.verifyWebhookSignature(rawBody, signature)) {
      return res.status(400).json({ error: 'Invalid Razorpay webhook signature.' });
    }

    const event = JSON.parse(rawBody.toString('utf8'));
    const eventId = getRazorpayEventId(event);

    if (eventId && processedRazorpayEvents.has(eventId)) {
      logger.info({ eventId, eventType: event.event }, 'Duplicate Razorpay webhook acknowledged');
      return res.json({ received: true, duplicate: true });
    }

    const syncPayload = await resolveRazorpaySyncPayload(event);

    if (syncPayload?.orgId) {
      await syncSubscriptionToSalesforce(syncPayload);
      logger.info({
        eventId,
        orgId: syncPayload.orgId,
        status: syncPayload.status,
        eventType: event.event
      }, 'Razorpay subscription synced to Salesforce');
    } else {
      logger.info({ eventId, eventType: event.event }, 'Razorpay event acknowledged without subscription sync');
    }

    if (eventId) {
      processedRazorpayEvents.add(eventId);
    }

    return res.json({ received: true });
  } catch (error) {
    logger.error({ error }, 'Failed to handle Razorpay webhook');
    return next(error);
  }
};

const createPortalSession = async (req, res, next) => {
  try {
    const { orgId } = req.body;

    if (!orgId) {
      return res.status(400).json({ error: 'orgId is required.' });
    }

    // Find customer by orgId
    const customer = await customerService.findCustomerByOrgId(orgId);
    if (!customer) {
      return res.status(404).json({ error: 'Customer not found.' });
    }

    const baseUrl = process.env.BILLING_RETURN_BASE_URL || `${req.protocol}://${req.get('host')}`;

    const session = await getStripe().billingPortal.sessions.create({
      customer: customer.id,
      return_url: `${baseUrl}/dashboard`
    });

    logger.info({ 
      customerId: customer.id,
      orgId 
    }, 'Portal session created');

    return res.status(200).json({ url: session.url });
  } catch (error) {
    logger.error({ error, orgId: req.body.orgId }, 'Failed to create portal session');
    return next(error);
  }
};

module.exports = {
  createCheckoutSession,
  handleWebhook,
  createPortalSession,
  resolveRazorpaySyncPayload,
  getRazorpayEventId
};
