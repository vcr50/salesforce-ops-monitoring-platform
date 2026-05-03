# SentinelFlow Development Guide

This guide covers development practices, code organization, and best practices for contributing to SentinelFlow.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Code Organization](#code-organization)
- [Adding New Features](#adding-new-features)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Code Review Guidelines](#code-review-guidelines)

## Overview

SentinelFlow is built with:
- **Frontend**: Custom JavaScript/HTML/CSS dashboard
- **Backend**: Node.js with Express
- **Platform**: Salesforce Experience Cloud
- **Database**: PostgreSQL
- **Queue**: Redis
- **AI**: Salesforce Agentforce

## Project Structure

```
SEOMP/
├── docs/                    # Documentation
│   ├── api.md              # API documentation
│   ├── architecture.md     # System architecture
│   ├── setup.md            # Setup guide
│   └── ...
├── force-app/              # Salesforce metadata
│   └── main/default/
│       ├── lwc/            # Lightning Web Components
│       ├── classes/        # Apex classes
│       ├── objects/        # Custom objects
│       └── ...
├── src/                    # Node.js application
│   ├── app.js             # Express app entry point
│   ├── config/            # Configuration files
│   ├── controllers/       # Request handlers
│   ├── routes/            # API routes
│   ├── services/          # Business logic
│   ├── middleware/        # Express middleware
│   ├── utils/             # Utility functions
│   └── dashboard/         # Frontend dashboard
│       ├── index.html
│       ├── style.css
│       └── app.js
├── tests/                  # Test files
├── scripts/                # Utility scripts
├── website/               # Marketing website
└── website-next/          # Next.js website (future)
```

## Development Workflow

### 1. Setup Development Environment

Follow the [Setup Guide](setup.md) to configure your development environment.

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b bugfix/your-bugfix-name
```

### 3. Make Changes

- Write code following [Best Practices](#best-practices)
- Add tests for new functionality
- Update documentation as needed

### 4. Test Your Changes

```bash
# Run tests
npm test

# Run linter
npm run lint

# Manually test the application
npm run dev
```

### 5. Commit Changes

Follow [Commit Message Conventions](../CONTRIBUTING.md#commit-message-conventions):

```bash
git add .
git commit -m "feat(incidents): add filtering by severity"
```

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Create a PR following the [Pull Request Process](../CONTRIBUTING.md#pull-request-process).

## Code Organization

### Backend (Node.js)

#### Controllers (`src/controllers/`)

Handle HTTP requests and responses.

Example:
```javascript
const { logger } = require('../middleware/logger');

/**
 * Get system context information
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getSystemContext = async (req, res) => {
  try {
    const context = await fetchSystemContext();
    logger.info({ context }, 'System context retrieved');
    res.json({ success: true, data: context });
  } catch (error) {
    logger.error({ error }, 'Failed to get system context');
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};
```

#### Routes (`src/routes/`)

Define API endpoints and map to controllers.

Example:
```javascript
const express = require('express');
const router = express.Router();
const systemController = require('../controllers/systemController');

// GET /api/system/context
router.get('/context', systemController.getSystemContext);

// GET /api/system/readiness
router.get('/readiness', systemController.getReadiness);

module.exports = router;
```

#### Services (`src/services/`)

Contain business logic and external integrations.

Example:
```javascript
const jsforce = require('jsforce');

class SalesforceService {
  constructor() {
    this.conn = new jsforce.Connection({
      loginUrl: process.env.SALESFORCE_INSTANCE_URL
    });
  }

  async connect() {
    await this.conn.login(
      process.env.SALESFORCE_USERNAME,
      process.env.SALESFORCE_PASSWORD + process.env.SALESFORCE_SECURITY_TOKEN
    );
  }

  async query(soql) {
    return await this.conn.query(soql);
  }
}

module.exports = new SalesforceService();
```

#### Middleware (`src/middleware/`)

Express middleware for cross-cutting concerns.

Example:
```javascript
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'development' 
    ? { target: 'pino-pretty' }
    : undefined
});

module.exports = { logger };
```

#### Utils (`src/utils/`)

Reusable utility functions.

Example:
```javascript
/**
 * Format number as currency
 * @param {number} amount - Amount to format
 * @returns {string} Formatted currency string
 */
const formatCurrency = (amount) => {
  if (amount >= 1000000) {
    return `$${(amount / 1000000).toFixed(1)}M`;
  }
  if (amount >= 1000) {
    return `$${(amount / 1000).toFixed(0)}K`;
  }
  return `$${amount}`;
};

module.exports = { formatCurrency };
```

### Frontend (Dashboard)

#### HTML Structure

Organize HTML with semantic elements and clear IDs/classes.

```html
<div class="page" id="page-incidents">
  <header class="page-header">
    <h1>Incidents</h1>
  </header>
  <main class="page-content">
    <table id="incidentTable">
      <!-- Table content -->
    </table>
  </main>
</div>
```

#### CSS Organization

Use BEM-like naming for CSS classes.

```css
/* Block */
.incident-table { }

/* Element */
.incident-table__header { }
.incident-table__row { }
.incident-table__cell { }

/* Modifier */
.incident-table__row--critical { }
.incident-table__cell--highlighted { }
```

#### JavaScript Structure

Organize JavaScript into clear sections.

```javascript
// ── DATA ─────────────────────────────────────────────────────────────
const INCIDENTS = [ ... ];

// ── HELPERS ──────────────────────────────────────────────────────────
function formatSeverity(severity) { ... }

// ── RENDERERS ───────────────────────────────────────────────────────
function renderIncidents(data) { ... }

// ── EVENT HANDLERS ─────────────────────────────────────────────────
function handleFilterChange(event) { ... }

// ── INITIALIZATION ──────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  renderIncidents(INCIDENTS);
});
```

### Salesforce

#### Apex Classes

Organize Apex classes by responsibility.

```java
/**
 * Controller for incident operations
 */
public with sharing class IncidentController {

    /**
     * Retrieve incidents based on criteria
     * @param status Status to filter by
     * @return List of incidents
     */
    public static List<Incident__c> getIncidents(String status) {
        String query = 'SELECT Id, Name, Status__c, Severity__c ' +
                      'FROM Incident__c';
        if (status != null) {
            query += ' WHERE Status__c = :status';
        }
        return Database.query(query);
    }
}
```

#### Lightning Web Components

Follow LWC best practices.

```javascript
// incidentList.js
import { LightningElement, api, wire } from 'lwc';
import getIncidents from '@salesforce/apex/IncidentController.getIncidents';

export default class IncidentList extends LightningElement {
    @api status;
    incidents;
    error;

    @wire(getIncidents, { status: '$status' })
    wiredIncidents({ error, data }) {
        if (data) {
            this.incidents = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.incidents = undefined;
        }
    }
}
```

## Adding New Features

### Example: Adding a New API Endpoint

1. **Create Controller Method** (in `src/controllers/`):

```javascript
const getNewFeature = async (req, res) => {
  try {
    const data = await fetchFeatureData();
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};
```

2. **Add Route** (in `src/routes/`):

```javascript
router.get('/new-feature', controller.getNewFeature);
```

3. **Write Tests** (in `tests/`):

```javascript
describe('GET /api/new-feature', () => {
  it('should return feature data', async () => {
    const response = await request(app)
      .get('/api/new-feature')
      .expect(200);
    expect(response.body.success).toBe(true);
  });
});
```

4. **Update Documentation** (in `docs/api.md`):

```markdown
### GET /api/new-feature

Returns feature data.

**Response:**
\`\`\`json
{
  "success": true,
  "data": { ... }
}
\`\`\`
```

### Example: Adding a New Dashboard Page

1. **Create HTML** (in `src/dashboard/`):

```html
<div class="page" id="page-new-feature">
  <h1>New Feature</h1>
  <div id="newFeatureContent"></div>
</div>
```

2. **Add CSS** (in `src/dashboard/style.css`):

```css
#page-new-feature {
  padding: 20px;
}
```

3. **Add JavaScript** (in `src/dashboard/app.js`):

```javascript
function renderNewFeature() {
  const content = el('newFeatureContent');
  if (content) {
    content.innerHTML = '<p>Feature content</p>';
  }
}
```

4. **Update Navigation** (in `src/dashboard/app.js`):

```javascript
if (page === 'new-feature') renderNewFeature();
```

## Best Practices

### General

- Keep functions small and focused
- Use descriptive variable and function names
- Add comments for complex logic
- Follow DRY (Don't Repeat Yourself)
- Write tests for new code
- Update documentation

### Backend

- Use async/await for asynchronous operations
- Handle errors gracefully
- Validate input data
- Use environment variables for configuration
- Implement proper logging
- Use appropriate HTTP status codes

### Frontend

- Keep JavaScript modular
- Use semantic HTML
- Follow CSS naming conventions
- Optimize for performance
- Ensure accessibility
- Test across browsers

### Salesforce

- Follow Salesforce naming conventions
- Use proper exception handling
- Write test classes with good coverage
- Follow governor limits best practices
- Use bulk operations for large datasets
- Implement proper security (sharing, CRUD/FLS)

## Common Patterns

### Error Handling

```javascript
try {
  const result = await operation();
  res.json({ success: true, data: result });
} catch (error) {
  logger.error({ error }, 'Operation failed');
  res.status(500).json({ 
    success: false, 
    error: error.message 
  });
}
```

### Data Validation

```javascript
const validateIncident = (data) => {
  const errors = [];
  if (!data.severity) errors.push('Severity is required');
  if (!data.description) errors.push('Description is required');
  return errors;
};
```

### Async Operations

```javascript
const fetchData = async () => {
  try {
    const [incidents, integrations] = await Promise.all([
      fetchIncidents(),
      fetchIntegrations()
    ]);
    return { incidents, integrations };
  } catch (error) {
    logger.error({ error }, 'Failed to fetch data');
    throw error;
  }
};
```

## Code Review Guidelines

### For Reviewers

1. Check code follows style guidelines
2. Verify tests are adequate
3. Ensure documentation is updated
4. Look for security issues
5. Check for performance concerns
6. Verify error handling
7. Test the changes if possible

### For Authors

1. Keep PRs focused and small
2. Provide clear description
3. Link related issues
4. Respond to feedback promptly
5. Update based on reviews
6. Ensure tests pass
7. Update CHANGELOG.md

## Additional Resources

- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [Salesforce Developer Guide](https://developer.salesforce.com/docs)
- [JavaScript Style Guide](https://github.com/airbnb/javascript)
