# SentinelFlow Testing Guide

This guide covers testing practices, running tests, and writing tests for SentinelFlow.

## Table of Contents

- [Overview](#overview)
- [Testing Stack](#testing-stack)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Test Structure](#test-structure)
- [Best Practices](#best-practices)
- [CI/CD Integration](#cicd-integration)
- [Test Coverage](#test-coverage)

## Overview

SentinelFlow uses a comprehensive testing approach including:
- Unit tests for individual functions and components
- Integration tests for API endpoints
- End-to-end tests for critical user flows
- Salesforce Apex tests for server-side logic

## Testing Stack

### JavaScript/Node.js

- **Jest**: Testing framework
- **Supertest**: HTTP assertion library for API testing
- **jest-coverage-thresholds**: Enforce coverage requirements

### Salesforce Apex

- **Salesforce Test Framework**: Built-in Apex testing
- **Apex Test Runner**: Via Salesforce CLI

## Running Tests

### All Tests

```bash
npm test
```

### With Coverage Report

```bash
npm run test:coverage
```

### Specific Test File

```bash
npm test -- path/to/test.test.js
```

### Watch Mode

```bash
npm run test:watch
```

### Salesforce Apex Tests

```bash
# Run all Apex tests
sf apex run test --target-org sentinelFlow-dev-edition

# Run specific test class
sf apex run test --class-name YourTestClass --target-org sentinelFlow-dev-edition

# Run tests with code coverage
sf apex run test --code-coverage --target-org sentinelFlow-dev-edition
```

## Writing Tests

### Unit Tests

Unit tests should focus on testing individual functions in isolation.

Example:

```javascript
// tests/unit/utils.test.js
const { formatMoney, riskClass } = require('../../src/utils/formatters');

describe('formatMoney', () => {
  it('should format small amounts correctly', () => {
    expect(formatMoney(500)).toBe('$500');
  });

  it('should format thousands with K suffix', () => {
    expect(formatMoney(1500)).toBe('$2K');
  });

  it('should format millions with M suffix', () => {
    expect(formatMoney(1500000)).toBe('$2M');
  });

  it('should handle zero', () => {
    expect(formatMoney(0)).toBe('$0');
  });
});

describe('riskClass', () => {
  it('should return correct class for Critical', () => {
    expect(riskClass('Critical')).toBe('risk-critical');
  });

  it('should return correct class for High', () => {
    expect(riskClass('High')).toBe('risk-high');
  });

  it('should return default class for unknown risk', () => {
    expect(riskClass('Unknown')).toBe('risk-low');
  });
});
```

### API Integration Tests

Test API endpoints with Supertest.

Example:

```javascript
// tests/integration/api.test.js
const request = require('supertest');
const app = require('../../src/app');

describe('API Endpoints', () => {
  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ok');
      expect(response.body).toHaveProperty('platform');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('GET /api/system/context', () => {
    it('should return system context', async () => {
      const response = await request(app)
        .get('/api/system/context')
        .expect('Content-Type', /json/)
        .expect(200);

      expect(response.body).toHaveProperty('platform');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('services');
    });
  });
});
```

### Controller Tests

Test controllers with mocked dependencies.

Example:

```javascript
// tests/unit/controllers/systemController.test.js
const { getSystemContext, getReadiness } = require('../../src/controllers/systemController');
const { sentinelFlowConfig, getFoundationStatus } = require('../../src/config/sentinelFlow');

jest.mock('../../src/config/sentinelFlow');

describe('System Controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getSystemContext', () => {
    it('should return system context', () => {
      const mockConfig = {
        platform: { name: 'SentinelFlow' },
        environment: { nodeEnv: 'development' },
        services: {},
        salesforce: { customObjects: {} }
      };

      sentinelFlowConfig.mockReturnValue(mockConfig);

      const req = {};
      const res = {
        json: jest.fn()
      };

      getSystemContext(req, res);

      expect(res.json).toHaveBeenCalledWith({
        platform: mockConfig.platform,
        environment: mockConfig.environment,
        services: mockConfig.services,
        salesforce: mockConfig.salesforce,
        timestamp: expect.any(String)
      });
    });
  });

  describe('getReadiness', () => {
    it('should return readiness status', () => {
      const mockStatus = {
        phase: 'phase-1-foundation',
        ready: true,
        missingEnv: [],
        workstreams: {}
      };

      getFoundationStatus.mockReturnValue(mockStatus);

      const req = {};
      const res = {
        json: jest.fn()
      };

      getReadiness(req, res);

      expect(res.json).toHaveBeenCalledWith({
        status: 'ok',
        readiness: mockStatus,
        timestamp: expect.any(String)
      });
    });
  });
});
```

### Apex Tests

Write Apex test classes following Salesforce best practices.

Example:

```java
@isTest
private class IncidentControllerTest {
    @testSetup
    static void setup() {
        // Create test data
        Incident__c incident = new Incident__c(
            Severity__c = 'Critical',
            Status__c = 'Open',
            Description__c = 'Test incident'
        );
        insert incident;
    }

    @isTest
    static void testGetIncidents() {
        Test.startTest();
        List<Incident__c> incidents = IncidentController.getIncidents();
        Test.stopTest();

        System.assertEquals(1, incidents.size());
        System.assertEquals('Critical', incidents[0].Severity__c);
    }

    @isTest
    static void testUpdateIncidentStatus() {
        Incident__c incident = [SELECT Id FROM Incident__c LIMIT 1];

        Test.startTest();
        IncidentController.updateStatus(incident.Id, 'Investigating');
        Test.stopTest();

        incident = [SELECT Status__c FROM Incident__c WHERE Id = :incident.Id];
        System.assertEquals('Investigating', incident.Status__c);
    }
}
```

## Test Structure

```
tests/
├── unit/              # Unit tests
│   ├── controllers/
│   ├── services/
│   ├── utils/
│   └── middleware/
├── integration/       # Integration tests
│   ├── api/
│   └── database/
├── e2e/              # End-to-end tests
│   ├── flows/
│   └── scenarios/
└── fixtures/         # Test data
    ├── incidents.json
    └── integrations.json
```

## Best Practices

### General

1. **Test Isolation**: Each test should be independent
2. **Clear Names**: Use descriptive test names
3. **Arrange-Act-Assert**: Structure tests clearly
4. **Mock External Dependencies**: Don't make real API calls
5. **Test Edge Cases**: Test boundaries and error conditions
6. **Keep Tests Fast**: Avoid slow operations in tests

### JavaScript/Node.js

1. **Use async/await**: For asynchronous code
2. **Mock appropriately**: Only mock what's necessary
3. **Clean up**: Clean up mocks in afterEach
4. **Use test doubles**: For complex dependencies

### Salesforce Apex

1. **Use @testSetup**: For common test data
2. **Test Positive and Negative**: Both success and failure cases
3. **Assert Properly**: Use meaningful assertions
4. **Avoid SeeAllData**: Don't use real org data
5. **Achieve 75%+ Coverage**: Required for deployment

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'

      - name: Install dependencies
        run: npm install

      - name: Run tests
        run: npm test

      - name: Generate coverage
        run: npm run test:coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v2
```

## Test Coverage

### Coverage Requirements

- **Overall**: Minimum 80%
- **Critical Paths**: 90%+
- **Utilities/Helpers**: 95%+

### Coverage Report

```bash
npm run test:coverage
```

This generates a coverage report in `coverage/` directory.

### Viewing Coverage

Open `coverage/lcov-report/index.html` in your browser to see detailed coverage information.

## Troubleshooting

### Tests Failing Locally

1. Clear cache:
   ```bash
   npm run test:clear-cache
   ```

2. Reinstall dependencies:
   ```bash
   rm -rf node_modules
   npm install
   ```

3. Check environment variables:
   ```bash
   cat .env
   ```

### Slow Tests

1. Use mocks for external services
2. Optimize database operations
3. Run tests in parallel where possible

### Flaky Tests

1. Ensure proper cleanup in afterEach
2. Avoid time-based assertions
3. Use deterministic test data

## Additional Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest Documentation](https://github.com/visionmedia/supertest)
- [Salesforce Testing Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing.htm)
- [Testing Best Practices](https://martinfowler.com/bliki/UnitTest.html)
