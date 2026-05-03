# Frequently Asked Questions (FAQ)

This document answers common questions about SentinelFlow.

## Table of Contents

- [General Questions](#general-questions)
- [Setup and Installation](#setup-and-installation)
- [Development](#development)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Salesforce Integration](#salesforce-integration)
- [Features and Functionality](#features-and-functionality)

## General Questions

### What is SentinelFlow?

SentinelFlow is an AI-powered incident intelligence platform built on Salesforce Experience Cloud and Agentforce. It helps operations teams detect, analyze, and resolve system failures with full business impact visibility.

### What are the key features?

- Real-time incident monitoring
- AI-powered root cause analysis
- Business impact calculation
- Auto-healing capabilities
- Integration monitoring
- Activity timeline
- Custom dashboard

### What technologies does SentinelFlow use?

- **Frontend**: Custom JavaScript/HTML/CSS
- **Backend**: Node.js with Express
- **Platform**: Salesforce Experience Cloud
- **AI**: Salesforce Agentforce
- **Database**: PostgreSQL
- **Queue**: Redis

### Is SentinelFlow open source?

Yes, SentinelFlow is open source under the MIT License. See LICENSE file for details.

## Setup and Installation

### How do I get started with SentinelFlow?

Follow the [Setup Guide](setup.md) for detailed installation instructions. The basic steps are:

1. Clone the repository
2. Install dependencies: `npm install`
3. Configure environment variables
4. Start the development server: `npm run dev`

### What are the system requirements?

- Node.js >= 16.0.0
- npm or yarn
- Git
- Salesforce CLI (sf)
- A Salesforce Developer Edition org

Optional:
- PostgreSQL >= 12
- Redis >= 6

### Do I need a Salesforce org?

Yes, you need a Salesforce Developer Edition org for full functionality. You can sign up for free at [developer.salesforce.com](https://developer.salesforce.com/signup).

### How do I configure environment variables?

Copy `.env.example` to `.env` and update with your values:

```bash
cp .env.example .env
# Edit .env with your configuration
```

See the [Setup Guide](setup.md) for details on required variables.

## Development

### How do I run the development server?

```bash
npm run dev
```

This starts the server with auto-reload using nodemon.

### How do I run tests?

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test file
npm test -- path/to/test.test.js
```

### How do I contribute to SentinelFlow?

Please read the [Contributing Guidelines](../CONTRIBUTING.md) for information on:
- Development workflow
- Code style guidelines
- Commit message conventions
- Pull request process

### Where can I find the API documentation?

The API documentation is available at [docs/api.md](api.md).

### How do I debug issues?

See the [Debugging Guide](debugging.md) for comprehensive debugging information.

## Deployment

### How do I deploy SentinelFlow to production?

See the [Setup Guide](setup.md#production-deployment) for deployment instructions. Options include:

- Heroku
- Docker
- AWS/GCP/Azure

### What environment variables are required for production?

Required production variables:
- `NODE_ENV=production`
- `SESSION_SECRET` (strong random value)
- `DATABASE_URL` (production database)
- `REDIS_URL` (production Redis)
- `SALESFORCE_CLIENT_ID`
- `SALESFORCE_CLIENT_SECRET`
- `ALLOWED_ORIGINS` (production domain)

See `.env.example` for a complete list.

### How do I configure HTTPS?

For production deployment:
1. Obtain SSL certificate from your hosting provider
2. Configure your web server (Nginx, Apache, etc.) to use HTTPS
3. Update `ALLOWED_ORIGINS` to use HTTPS URLs
4. Enable secure cookies in session configuration

## Troubleshooting

### Port 3000 is already in use

Either:
- Kill the process using port 3000
- Change the PORT in your `.env` file:
  ```
  PORT=3001
  ```

### Database connection failed

1. Verify PostgreSQL is running
2. Check DATABASE_URL in `.env`
3. Ensure database exists: `createdb sentinelflow`
4. Check connection credentials

### Salesforce authentication failed

1. Verify credentials in `.env`
2. Check Connected App configuration
3. Ensure security token is correct
4. Try re-authenticating: `sf org login web`

### Tests are failing

1. Clear cache: `npm run test:clear-cache`
2. Reinstall dependencies:
   ```bash
   rm -rf node_modules
   npm install
   ```
3. Check environment variables
4. Review test output for specific errors

### Dashboard not loading data

1. Check browser console for errors
2. Verify API is responding: `curl http://localhost:3000/health`
3. Check network tab in DevTools for failed requests
4. Verify data exists in database

## Salesforce Integration

### How do I set up the Connected App?

See the [Developer Org Setup Guide](developer-org-setup.md) for detailed instructions.

### What Salesforce permissions are needed?

The following permission sets are used:
- `SentinelFlow_Runtime_Admin`: Full access
- `SentinelFlow_Portal_Support`: Edit incidents
- `SentinelFlow_Portal_Viewer`: Read-only access

See the [Architecture Documentation](architecture.md) for details.

### How do I deploy metadata to Salesforce?

```bash
sf project deploy start -d force-app -o your-org-alias
```

### How do I run Apex tests?

```bash
sf apex run test --target-org your-org-alias
```

### Can I use a production Salesforce org?

Yes, but ensure you:
- Use proper security measures
- Configure appropriate permissions
- Test thoroughly in a sandbox first
- Follow Salesforce best practices

## Features and Functionality

### How does AI analysis work?

SentinelFlow uses Salesforce Agentforce to:
- Analyze incident data
- Identify root causes
- Recommend actions
- Calculate confidence scores

See the [Product Design Document](sentinelflow-product-design.md) for details.

### What is auto-healing?

Auto-healing automatically resolves incidents when:
- AI confidence score is high (>85%)
- Recommended action is safe to execute
- Incident type supports automation

Actions include:
- Retry failed operations
- Restart services
- Re-authenticate connections

### How is business impact calculated?

Business impact is calculated as:

```
Revenue Loss = Users Affected × Average Revenue Per User
```

Risk levels:
- Critical: >$50,000
- High: $10,000-$50,000
- Medium: $1,000-$10,000
- Low: <$1,000

### Can I customize the dashboard?

Yes, the dashboard is fully customizable. You can:
- Modify HTML in `src/dashboard/index.html`
- Update styles in `src/dashboard/style.css`
- Add functionality in `src/dashboard/app.js`

See the [Development Guide](development.md) for details.

### How do I add new integrations?

1. Create integration log entries in `Integration_Log__c`
2. Configure monitoring thresholds
3. Set up Platform Events for failures
4. Update the dashboard to display integration status

See the [Architecture Documentation](architecture.md) for details.

### Is real-time updates supported?

Yes, real-time updates are supported via:
- Platform Events (Salesforce)
- Streaming API (CometD)
- WebSocket connections

See the [Product Design Document](sentinelflow-product-design.md) for implementation details.

## Getting Help

### Where can I find more documentation?

All documentation is in the `docs/` directory:
- [API Documentation](api.md)
- [Architecture](architecture.md)
- [Setup Guide](setup.md)
- [Development Guide](development.md)
- [Testing Guide](testing.md)
- [Debugging Guide](debugging.md)
- [Product Design](sentinelflow-product-design.md)

### How do I report a bug?

Please create an issue on GitHub with:
- Detailed description
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Error messages and logs

### How do I request a feature?

Please create an issue on GitHub with:
- Feature description
- Use case
- Proposed implementation (if known)
- Any relevant examples or references

### Where can I get community support?

- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share ideas
- Documentation: Check docs/ directory for guides

### Is commercial support available?

For commercial support inquiries, please contact [contact@tomcodex.com](mailto:contact@tomcodex.com).

## Additional Resources

- [SentinelFlow README](../README.md)
- [Salesforce Developer Documentation](https://developer.salesforce.com/docs)
- [Node.js Documentation](https://nodejs.org/docs/)
- [Express.js Documentation](https://expressjs.com/)
