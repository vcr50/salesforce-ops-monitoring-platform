describe('architecture support modules', () => {
  afterEach(() => {
    jest.useRealTimers();
    delete process.env.SALESFORCE_INSTANCE_URL;
    delete process.env.API_TIMEOUT;
    delete process.env.RETRY_ATTEMPTS;
    delete process.env.RETRY_DELAY;
  });

  test('constants read environment values lazily', () => {
    const constants = require('../src/utils/constants');

    process.env.SALESFORCE_INSTANCE_URL = 'https://example.my.salesforce.com/';
    process.env.API_TIMEOUT = '1234';
    process.env.RETRY_ATTEMPTS = '5';
    process.env.RETRY_DELAY = '250';

    expect(constants.SALESFORCE_TOKEN_URL).toBe('https://example.my.salesforce.com/services/oauth2/token');
    expect(constants.API_TIMEOUT).toBe(1234);
    expect(constants.RETRY_ATTEMPTS).toBe(5);
    expect(constants.RETRY_DELAY).toBe(250);

    process.env.SALESFORCE_INSTANCE_URL = 'https://changed.my.salesforce.com';
    expect(constants.SALESFORCE_REST_API_BASE).toBe('https://changed.my.salesforce.com/services/data');
  });

  test('idempotency service evicts expired event ids and can be cleared', () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    const { IdempotencyService } = require('../src/services/idempotencyService');
    const service = new IdempotencyService(1000);

    service.mark('evt_1');
    expect(service.has('evt_1')).toBe(true);
    expect(service.size).toBe(1);

    jest.advanceTimersByTime(1001);
    expect(service.has('evt_1')).toBe(false);
    expect(service.size).toBe(0);

    service.mark('evt_2');
    service.clear();
    expect(service.size).toBe(0);
  });

  test('container supports resettable registrations and default service wiring', () => {
    const container = require('../src/container');

    container.reset();
    container.register('example', { ok: true });
    expect(container.resolve('example')).toEqual({ ok: true });

    container.reset();
    expect(container.has('example')).toBe(false);
    expect(() => container.registerDefaults()).not.toThrow();
    expect(container.has('httpClient')).toBe(true);
    expect(container.has('dataSyncService')).toBe(true);
  });
});
