const {
  mapStripeStatus,
  mapSubscriptionForSalesforce,
  mapRazorpayStatus,
  mapRazorpaySubscriptionForSalesforce,
  getBillingEmailFromOrgId,
  normalizeOrgIdForSalesforce
} = require('../src/services/subscriptionSyncService');

describe('subscriptionSyncService', () => {
  test('maps Stripe lifecycle statuses to Salesforce values', () => {
    expect(mapStripeStatus('active')).toBe('Active');
    expect(mapStripeStatus('trialing')).toBe('Active');
    expect(mapStripeStatus('past_due')).toBe('Past Due');
    expect(mapStripeStatus('canceled')).toBe('Canceled');
    expect(mapStripeStatus('unrecognized')).toBe('Expired');
  });

  test('maps Stripe subscription metadata for Salesforce sync', () => {
    const payload = mapSubscriptionForSalesforce({
      id: 'sub_123',
      customer: 'cus_123',
      status: 'active',
      current_period_end: 1735689600,
      metadata: {
        orgId: '00D000000000001AAA',
        plan: 'Professional'
      }
    }, 'invoice.paid');

    expect(payload).toEqual({
      orgId: '00D000000000001AAA',
      plan: 'Professional',
      status: 'Active',
      expiryDate: '2025-01-01',
      stripeCustomerId: 'cus_123',
      stripeSubscriptionId: 'sub_123',
      eventName: 'invoice.paid',
      billingEmail: null
    });
  });

  test('maps Razorpay lifecycle statuses to Salesforce values', () => {
    expect(mapRazorpayStatus('active')).toBe('Active');
    expect(mapRazorpayStatus('authenticated')).toBe('Active');
    expect(mapRazorpayStatus('pending')).toBe('Past Due');
    expect(mapRazorpayStatus('halted')).toBe('Past Due');
    expect(mapRazorpayStatus('cancelled')).toBe('Canceled');
    expect(mapRazorpayStatus('completed')).toBe('Expired');
  });

  test('maps Razorpay subscription notes for Salesforce sync', () => {
    const payload = mapRazorpaySubscriptionForSalesforce({
      id: 'sub_razorpay_123',
      customer_id: 'cust_razorpay_123',
      status: 'active',
      current_end: 1735689600,
      notes: {
        orgId: '00D000000000001AAA',
        plan: 'Professional'
      }
    }, 'subscription.activated');

    expect(payload).toEqual({
      orgId: '00D000000000001AAA',
      plan: 'Professional',
      status: 'Active',
      expiryDate: '2025-01-01',
      stripeCustomerId: 'cust_razorpay_123',
      stripeSubscriptionId: 'sub_razorpay_123',
      eventName: 'subscription.activated',
      billingEmail: null
    });
  });

  test('normalizes website lead references for Salesforce org id length', () => {
    expect(getBillingEmailFromOrgId('web-lead:buyer@example.com')).toBe('buyer@example.com');
    expect(getBillingEmailFromOrgId('00D000000000001AAA')).toBeNull();

    const normalized = normalizeOrgIdForSalesforce('web-lead:buyer@example.com');
    expect(normalized).toMatch(/^WL[a-f0-9]{16}$/);
    expect(normalized.length).toBe(18);
    expect(normalizeOrgIdForSalesforce('00D000000000001AAA')).toBe('00D000000000001AAA');
  });
});
