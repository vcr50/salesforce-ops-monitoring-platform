const crypto = require('crypto');
const { verifyWebhookSignature } = require('../src/services/razorpayService');

describe('razorpayService', () => {
  test('verifies Razorpay webhook signatures', () => {
    const secret = 'test_secret';
    const rawBody = Buffer.from(JSON.stringify({ event: 'subscription.activated' }));
    const signature = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    expect(verifyWebhookSignature(rawBody, signature, secret)).toBe(true);
    expect(verifyWebhookSignature(rawBody, '00'.repeat(32), secret)).toBe(false);
  });
});
