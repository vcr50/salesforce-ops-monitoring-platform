const request = require('supertest');

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

jest.mock('../src/services/stripeClient', () => ({
  getStripe: jest.fn(),
  resetStripeInstance: jest.fn()
}));

jest.mock('../src/services/billingProviderService', () => ({
  getBillingProvider: jest.fn()
}));

const razorpayService = require('../src/services/razorpayService');
const { getStripe } = require('../src/services/stripeClient');
const { getBillingProvider } = require('../src/services/billingProviderService');
const { app } = require('../src/app');

describe('app integration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('GET /health returns platform info', async () => {
    const response = await request(app).get('/health').expect(200);

    expect(response.body).toEqual(expect.objectContaining({
      status: 'ok',
      platform: expect.any(String),
      phase: expect.any(String),
      readiness: expect.any(Object),
      timestamp: expect.any(String),
      uptime: expect.any(Number)
    }));
  });

  test('GET /nonexistent returns 404', async () => {
    const response = await request(app).get('/nonexistent').expect(404);

    expect(response.body).toEqual({
      error: 'Not Found',
      path: '/nonexistent',
      method: 'GET'
    });
  });

  test('GET /api/system/readiness returns readiness status', async () => {
    const response = await request(app).get('/api/system/readiness').expect(200);

    expect(response.body).toEqual(expect.objectContaining({
      status: 'ok',
      readiness: expect.any(Object),
      timestamp: expect.any(String)
    }));
  });

  test('POST /api/billing/webhook routes Razorpay webhooks based on provider', async () => {
    getBillingProvider.mockReturnValue('razorpay');
    razorpayService.verifyWebhookSignature.mockReturnValue(true);

    const event = {
      id: 'evt_rzp_1',
      event: 'subscription.activated',
      payload: {
        subscription: {
          entity: {
            id: 'sub_123',
            customer_id: 'cust_123',
            status: 'active',
            current_end: 1735689600,
            notes: { orgId: '00D000000000001AAA', plan: 'Professional' }
          }
        }
      }
    };

    const response = await request(app)
      .post('/api/billing/webhook')
      .set('Content-Type', 'application/json')
      .set('x-razorpay-signature', 'valid')
      .send(JSON.stringify(event))
      .expect(200);

    expect(response.body).toEqual({ received: true });
    expect(razorpayService.verifyWebhookSignature).toHaveBeenCalled();
    expect(getStripe).not.toHaveBeenCalled();
  });

  test('POST /api/billing/webhook routes Stripe webhooks based on provider', async () => {
    getBillingProvider.mockReturnValue('stripe');
    const retrieve = jest.fn().mockResolvedValue({
      id: 'sub_123',
      customer: 'cus_123',
      status: 'active',
      current_period_end: 1735689600,
      metadata: { orgId: '00D000000000001AAA', plan: 'Professional' }
    });
    getStripe.mockReturnValue({
      webhooks: {
        constructEvent: jest.fn()
      },
      subscriptions: {
        retrieve
      }
    });

    const response = await request(app)
      .post('/api/billing/webhook')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({
        type: 'invoice.paid',
        data: {
          object: {
            subscription: 'sub_123'
          }
        }
      }))
      .expect(200);

    expect(response.body).toEqual({ received: true });
    expect(getStripe).toHaveBeenCalled();
    expect(retrieve).toHaveBeenCalledWith('sub_123');
    expect(razorpayService.verifyWebhookSignature).not.toHaveBeenCalled();
  });
});
