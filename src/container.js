
/**
 * Dependency Injection Container
 * Lightweight service locator that allows controllers and services
 * to receive their dependencies instead of hard-coupling via require().
 *
 * In production, call container.register() with real services.
 * In tests, call container.register() with mocks/stubs.
 */

const container = new Map();

const register = (name, service) => {
  container.set(name, service);
};

const resolve = (name) => {
  const service = container.get(name);
  if (!service) {
    throw new Error(`Service "${name}" is not registered in the DI container.`);
  }
  return service;
};

const has = (name) => container.has(name);

const reset = () => container.clear();

/**
 * Register all default (production) services.
 * Call this once at app startup.
 */
const registerDefaults = () => {
  register('config', require('./config'));
  register('httpClient', require('./services/httpClient'));
  register('stripeClient', require('./services/stripeClient'));
  register('idempotencyService', require('./services/idempotencyService'));
  register('customerService', require('./services/customerService'));
  register('subscriptionService', require('./services/subscriptionService'));
  register('razorpayService', require('./services/razorpayService'));
  register('billingProviderService', require('./services/billingProviderService'));
  register('subscriptionSyncService', require('./services/subscriptionSyncService'));
  register('cacheService', require('./services/cacheService'));
  register('salesforceService', require('./services/salesforceService'));
  register('analyticsService', require('./services/analyticsService'));
  register('customerPortalService', require('./services/customerPortalService'));
  register('dataSyncService', require('./modules/dataSync'));
};

module.exports = { register, resolve, has, reset, registerDefaults };
