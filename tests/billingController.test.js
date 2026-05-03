jest.mock('../src/services/razorpayService', () => ({
  verifyWebhookSignature: jest.fn(),
  createCheckoutSubscription: jest.fn(),
  getSubscription: jest.fn()
}));

jest.mock('../src/services/subscriptionSyncService', () => {
  const actual = jest.requireActual('../src/services/subscriptionSyncService');
  return {
    ...actual,
    syncSubscriptionToSalesforce: jest.fn().mockResolvedValue({ success: true })
  };
});

const razorpayService = require('../src/services/razorpayService');
const { syncSubscriptionToSalesforce } = require('../src/services/subscriptionSyncService');
const billingController = require('../src/controllers/billingController');

const createResponse = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

describe('billingController Razorpay flow', () => {
  beforeEach(() => {
    process.env.BILLING_PROVIDER = 'razorpay';
    process.env.BILLING_CURRENCY = 'INR';
    process.env.PROFESSIONAL_MONTHLY_AMOUNT_INR = '2499';
    jest.clearAllMocks();
  });

  test('rejects checkout without orgId', async () => {
    const req = { body: { email: 'buyer@example.com', plan: 'Professional' } };
    const res = createResponse();
    const next = jest.fn();

    await billingController.createCheckoutSession(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'orgId is required.' });
    expect(next).not.toHaveBeenCalled();
  });

  test('rejects Razorpay checkout without email', async () => {
    const req = { body: { orgId: '00D000000000001AAA', plan: 'Professional' } };
    const res = createResponse();
    const next = jest.fn();

    await billingController.createCheckoutSession(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'email is required.' });
    expect(next).not.toHaveBeenCalled();
  });

  test('rejects invalid checkout plan', async () => {
    const req = { body: { orgId: '00D000000000001AAA', email: 'buyer@example.com', plan: 'Gold' } };
    const res = createResponse();
    const next = jest.fn();

    await billingController.createCheckoutSession(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'Invalid plan: Gold' });
  });

  test('creates Razorpay checkout subscription', async () => {
    razorpayService.createCheckoutSubscription.mockResolvedValue({
      provider: 'razorpay',
      customerId: 'cust_123',
      subscriptionId: 'sub_123',
      url: 'https://rzp.io/i/sub_123'
    });

    const req = {
      body: {
        orgId: '00D000000000001AAA',
        email: 'buyer@example.com',
        name: 'Buyer',
        plan: 'Professional'
      }
    };
    const res = createResponse();
    const next = jest.fn();

    await billingController.createCheckoutSession(req, res, next);

    expect(razorpayService.createCheckoutSubscription).toHaveBeenCalledWith({
      orgId: '00D000000000001AAA',
      email: 'buyer@example.com',
      name: 'Buyer',
      plan: 'Professional'
    });
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      provider: 'razorpay',
      customerId: 'cust_123',
      subscriptionId: 'sub_123',
      url: 'https://rzp.io/i/sub_123'
    });
  });

  test('rejects invalid Razorpay webhook signatures', async () => {
    razorpayService.verifyWebhookSignature.mockReturnValue(false);
    const req = {
      body: Buffer.from(JSON.stringify({ event: 'subscription.activated' })),
      headers: { 'x-razorpay-signature': 'bad' }
    };
    const res = createResponse();
    const next = jest.fn();

    await billingController.handleWebhook(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'Invalid Razorpay webhook signature.' });
    expect(syncSubscriptionToSalesforce).not.toHaveBeenCalled();
  });

  test('syncs valid Razorpay subscription webhook', async () => {
    razorpayService.verifyWebhookSignature.mockReturnValue(true);
    const event = {
      event: 'subscription.activated',
      payload: {
        subscription: {
          entity: {
            id: 'sub_123',
            customer_id: 'cust_123',
            status: 'active',
            current_end: 1735689600,
            notes: {
              orgId: '00D000000000001AAA',
              plan: 'Professional'
            }
          }
        }
      }
    };
    const req = {
      body: Buffer.from(JSON.stringify(event)),
      headers: { 'x-razorpay-signature': 'valid' }
    };
    const res = createResponse();
    const next = jest.fn();

    await billingController.handleWebhook(req, res, next);

    expect(syncSubscriptionToSalesforce).toHaveBeenCalledWith({
      orgId: '00D000000000001AAA',
      plan: 'Professional',
      status: 'Active',
      expiryDate: '2025-01-01',
      stripeCustomerId: 'cust_123',
      stripeSubscriptionId: 'sub_123',
      eventName: 'subscription.activated',
      billingEmail: null
    });
    expect(res.json).toHaveBeenCalledWith({ received: true });
  });

  test('fetches Razorpay subscription for payment failure webhooks', async () => {
    razorpayService.verifyWebhookSignature.mockReturnValue(true);
    razorpayService.getSubscription.mockResolvedValue({
      id: 'sub_failed',
      customer_id: 'cust_failed',
      status: 'halted',
      current_end: 1735689600,
      notes: {
        orgId: '00D000000000002AAA',
        plan: 'Professional'
      }
    });
    const event = {
      event: 'payment.failed',
      payload: {
        payment: {
          entity: {
            id: 'pay_failed',
            subscription_id: 'sub_failed'
          }
        }
      }
    };
    const req = {
      body: Buffer.from(JSON.stringify(event)),
      headers: { 'x-razorpay-signature': 'valid' }
    };
    const res = createResponse();
    const next = jest.fn();

    await billingController.handleWebhook(req, res, next);

    expect(razorpayService.getSubscription).toHaveBeenCalledWith('sub_failed');
    expect(syncSubscriptionToSalesforce).toHaveBeenCalledWith({
      orgId: '00D000000000002AAA',
      plan: 'Professional',
      status: 'Past Due',
      expiryDate: '2025-01-01',
      stripeCustomerId: 'cust_failed',
      stripeSubscriptionId: 'sub_failed',
      eventName: 'payment.failed',
      billingEmail: null
    });
  });
});
