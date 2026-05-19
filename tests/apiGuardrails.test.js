const request = require('supertest');
process.env.RATE_LIMIT_DEFAULT = '2';
const { app } = require('../src/app');
const { tenantRateLimit } = require('../src/middleware/rateLimit');

describe('API AppExchange guardrails', () => {
  beforeEach(() => {
    tenantRateLimit._reset();
  });

  test('rejects API requests without Salesforce tenant context', async () => {
    const response = await request(app).get('/api/system/readiness');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('TENANT_CONTEXT_REQUIRED');
    expect(response.headers['x-request-id']).toBeDefined();
  });

  test('accepts API requests with Salesforce org context and propagates request id', async () => {
    const response = await request(app)
      .get('/api/system/readiness')
      .set('x-sf-org-id', '00D000000000001AAA')
      .set('x-sf-user-id', '005000000000001AAA')
      .set('x-request-id', 'req-unit-test');

    expect(response.status).toBe(200);
    expect(response.headers['x-request-id']).toBe('req-unit-test');
  });

  test('applies per-tenant rate limits by request family', async () => {
    tenantRateLimit._reset();

    for (let index = 0; index < 2; index += 1) {
      await request(app)
        .get('/api/system/readiness')
        .set('x-sf-org-id', '00D000000000001AAA');
    }

    const response = await request(app)
      .get('/api/system/readiness')
      .set('x-sf-org-id', '00D000000000001AAA');

    expect(response.status).toBe(429);
    expect(response.body.error.code).toBe('TENANT_RATE_LIMIT_EXCEEDED');
  });

  test('rejects payload org ids that do not match request context', async () => {
    const response = await request(app)
      .post('/api/analytics/event')
      .set('x-sf-org-id', '00D000000000001AAA')
      .send({
        eventName: 'incident_detected',
        data: {
          orgId: '00D000000000002AAA'
        }
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('TENANT_CONTEXT_MISMATCH');
    expect(response.body.error.conflicts[0].field).toBe('body.data.orgId');
  });

  test('rejects invalid query input before controller execution', async () => {
    const response = await request(app)
      .get('/api/analytics/report?startDate=05-12-2026')
      .set('x-sf-org-id', '00D000000000001AAA');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_START_DATE');
  });
});
