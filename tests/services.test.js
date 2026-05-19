const { getBillingProvider } = require('../src/services/billingProviderService');
const {
  getPlans,
  getPlanByName,
  getPlanById,
  normalizePlanName
} = require('../src/services/subscriptionService');
const { IdempotencyService } = require('../src/services/idempotencyService');
const { CacheService } = require('../src/services/cacheService');
const { DataSyncService } = require('../src/modules/dataSync');

describe('billingProviderService', () => {
  const originalProvider = process.env.BILLING_PROVIDER;

  afterEach(() => {
    if (originalProvider === undefined) {
      delete process.env.BILLING_PROVIDER;
    } else {
      process.env.BILLING_PROVIDER = originalProvider;
    }
  });

  test('defaults to Stripe and accepts supported providers case-insensitively', () => {
    delete process.env.BILLING_PROVIDER;
    expect(getBillingProvider()).toBe('stripe');

    process.env.BILLING_PROVIDER = 'RAZORPAY';
    expect(getBillingProvider()).toBe('razorpay');

    process.env.BILLING_PROVIDER = 'stripe';
    expect(getBillingProvider()).toBe('stripe');
  });

  test('rejects unsupported providers', () => {
    process.env.BILLING_PROVIDER = 'paypal';
    expect(() => getBillingProvider()).toThrow('Unsupported billing provider: paypal');
  });
});

describe('subscriptionService plan metadata', () => {
  test('returns configured plans and looks them up by name or id', () => {
    const plans = getPlans();

    expect(plans.map((plan) => plan.name)).toEqual(['Starter', 'Professional', 'Enterprise']);
    expect(getPlanByName(' professional ')).toMatchObject({ name: 'Professional' });
    expect(getPlanByName('missing')).toBeUndefined();
    expect(getPlanById('starter')).toMatchObject({ name: 'Starter' });
    expect(getPlanById('Enterprise')).toMatchObject({ id: 'enterprise' });
  });

  test('normalizes plan names', () => {
    expect(normalizePlanName(' Professional ')).toBe('professional');
    expect(normalizePlanName(null)).toBe('');
  });
});

describe('IdempotencyService', () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  test('tracks, clears, and reports event ids', () => {
    const service = new IdempotencyService(1000);

    expect(service.has(null)).toBe(false);
    service.mark('evt_1');

    expect(service.has('evt_1')).toBe(true);
    expect(service.size).toBe(1);

    service.clear();
    expect(service.has('evt_1')).toBe(false);
    expect(service.size).toBe(0);
  });

  test('evicts expired events through cleanup', () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    const service = new IdempotencyService(1000);

    service.mark('evt_old');
    jest.advanceTimersByTime(1001);
    service.mark('evt_new');

    expect(service.cleanup()).toBe(1);
    expect(service.has('evt_old')).toBe(false);
    expect(service.has('evt_new')).toBe(true);
    expect(service.size).toBe(1);
  });
});

describe('CacheService', () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  test('sets, gets, checks, deletes, and clears cache values', () => {
    const cache = new CacheService(1000);

    cache.set('key', { ok: true });
    expect(cache.get('key')).toEqual({ ok: true });
    expect(cache.has('key')).toBe(true);
    expect(cache.getStats()).toEqual({ size: 1, ttl: 1000 });

    cache.delete('key');
    expect(cache.get('key')).toBeNull();

    cache.set('a', 1);
    cache.set('b', 2);
    cache.clear();
    expect(cache.getStats().size).toBe(0);
  });

  test('expires values on read and cleanup', () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    const cache = new CacheService(1000);

    cache.set('read-expired', 'value');
    jest.advanceTimersByTime(1001);
    expect(cache.get('read-expired')).toBeNull();

    cache.set('cleanup-expired', 'old', 500);
    cache.set('fresh', 'new', 2000);
    jest.advanceTimersByTime(501);
    expect(cache.cleanup()).toBe(1);
    expect(cache.get('cleanup-expired')).toBeNull();
    expect(cache.get('fresh')).toBe('new');
  });
});

describe('DataSyncService', () => {
  test('starts, updates, completes, and filters sync sessions', () => {
    const service = new DataSyncService();
    const accountSession = service.startSync('Account', 'to-salesforce');
    const contactSession = service.startSync('Contact');

    expect(accountSession).toMatchObject({
      objectName: 'Account',
      direction: 'to-salesforce',
      status: 'in-progress',
      recordsProcessed: 0,
      recordsFailed: 0
    });
    expect(service.getSyncStatus(accountSession.id)).toBe(accountSession);

    service.updateSync(accountSession.id, { recordsProcessed: 3 });
    service.completeSync(accountSession.id, true);
    service.completeSync(contactSession.id, false, 'boom');

    expect(service.getSyncLogs({ objectName: 'Account' })).toHaveLength(1);
    expect(service.getSyncLogs({ status: 'failed' })).toHaveLength(1);
    expect(service.getSyncLogs({ limit: 1 })[0]).toMatchObject({ objectName: 'Contact', error: 'boom' });
    expect(service.getSyncStatus('missing')).toBeNull();
    expect(() => service.updateSync('missing', {})).toThrow('Sync session missing not found');
    expect(() => service.completeSync('missing')).toThrow('Sync session missing not found');
  });

  test('resolves conflicts with each supported strategy', () => {
    const service = new DataSyncService();
    const local = { id: 'local', updatedAt: '2026-01-02T00:00:00.000Z', onlyLocal: true };
    const remote = { id: 'remote', LastModifiedDate: '2026-01-01T00:00:00.000Z', onlyRemote: true };

    expect(service.resolveConflict(local, remote, 'remote-wins')).toBe(remote);
    expect(service.resolveConflict(local, remote, 'local-wins')).toBe(local);
    expect(service.resolveConflict(local, remote, 'merge')).toEqual({ ...local, ...remote });
    expect(service.resolveConflict(local, remote, 'newer-wins')).toBe(local);
    expect(service.resolveConflict(
      { ...local, updatedAt: '2025-01-01T00:00:00.000Z' },
      remote,
      'newer-wins'
    )).toBe(remote);
    expect(service.resolveConflict(local, remote, 'unknown')).toBe(remote);
  });
});
