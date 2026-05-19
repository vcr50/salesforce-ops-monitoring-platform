
/**
 * Jest Global Setup
 * Centralizes environment stubs and common mocks so individual test files
 * don't need to repeat boilerplate.
 */

// Stub dotenv so it never reads a real .env during tests
jest.mock('dotenv', () => ({
  config: jest.fn()
}));

// Provide a no-op pino logger so test output stays clean
jest.mock('pino', () => {
  const noop = () => {};
  const logger = {
    info: noop,
    warn: noop,
    error: noop,
    debug: noop,
    trace: noop,
    fatal: noop,
    child: () => logger
  };
  return jest.fn(() => logger);
});

jest.mock('pino-http', () => {
  return jest.fn(() => (req, res, next) => next());
});

// Set a stable test environment
process.env.NODE_ENV = 'test';
process.env.PORT = '0'; // prevent server binding
process.env.LOG_LEVEL = 'silent';

// Stop background timers from cacheService so they don't leak across test runs
afterAll(() => {
  try {
    const { stopCleanupTimer } = require('../src/services/cacheService');
    stopCleanupTimer();
  } catch (_) {
    // Module may not be loaded in all test suites
  }

  try {
    const { stopCleanup } = require('../src/services/idempotencyService');
    stopCleanup();
  } catch (_) {
    // Module may not be loaded in all test suites
  }
});
