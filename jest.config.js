
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.js'],
  testPathIgnorePatterns: [
    "/node_modules/",
    "/\\.tmp-chrome",
    "/political-dashboard/",
    "/sentinelflow-dashboard/",
    "/website-next/"
  ],
  collectCoverageFrom: [
    'src/controllers/billingController.js',
    'src/services/razorpayService.js',
    'src/services/subscriptionSyncService.js',
    'src/services/idempotencyService.js',
    'src/services/stripeClient.js',
    'src/services/httpClient.js',
    'src/container.js',
    'src/utils/constants.js',
    'src/modules/restApi.js',
    'src/modules/soapApi.js',
    'src/modules/bulkApi.js',
    'src/modules/dataSync.js',
    'src/services/cacheService.js',
    'src/services/analyticsService.js'
  ],
  coverageThreshold: {
    global: {
      branches: 25,
      functions: 28,
      lines: 39,
      statements: 38
    }
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  coverageDirectory: 'tmp/coverage',
  verbose: true
};
