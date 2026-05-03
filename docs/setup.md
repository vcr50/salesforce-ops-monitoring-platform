# SentinelFlow Setup Guide

This guide will help you set up SentinelFlow for development and production use.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Salesforce Org Setup](#salesforce-org-setup)
- [Environment Configuration](#environment-configuration)
- [Running the Application](#running-the-application)
- [Verification Steps](#verification-steps)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

## Prerequisites

### Required Software

- **Node.js**: Version 16.0.0 or higher
  - Download from [nodejs.org](https://nodejs.org/)
  - Verify installation: `node --version`

- **npm**: Comes with Node.js
  - Verify installation: `npm --version`

- **Git**: For version control
  - Download from [git-scm.com](https://git-scm.com/)
  - Verify installation: `git --version`

- **Salesforce CLI (sf)**: For Salesforce deployment
  - Install: `npm install -g @salesforce/cli`
  - Verify installation: `sf --version`

### Required Accounts

- **Salesforce Developer Edition Org**
  - Sign up at [developer.salesforce.com](https://developer.salesforce.com/signup)
  - Free for development purposes

- **GitHub Account** (for contributing)
  - Sign up at [github.com](https://github.com)

### Optional Software

- **PostgreSQL**: For local development database
  - Download from [postgresql.org](https://www.postgresql.org/download/)
  - Version 12 or higher recommended

- **Redis**: For local queue development
  - Download from [redis.io](https://redis.io/download)
  - Version 6 or higher recommended

## Local Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/SEOMP.git
cd SEOMP
```

### 2. Install Dependencies

```bash
npm install
```

This will install all required Node.js packages listed in `package.json`.

### 3. Set Up Environment Variables

```bash
cp .env.example .env
```

Edit `.env` with your configuration. See [Environment Configuration](#environment-configuration) for details.

### 4. Initialize Database (Optional)

If using PostgreSQL locally:

```bash
# Create database
createdb sentinelflow

# Run migrations (if available)
npm run db:migrate
```

### 5. Start Redis (Optional)

If using Redis locally:

```bash
# On macOS with Homebrew
brew services start redis

# On Linux
sudo systemctl start redis

# On Windows
redis-server
```

## Salesforce Org Setup

### 1. Authenticate to Your Org

```bash
sf org login web -a sentinelFlow-dev-edition
```

This will open a browser window for authentication.

### 2. Create Connected App

1. Open Salesforce Setup
2. Navigate to `App Manager`
3. Click `New Connected App`
4. Fill in required fields:
   - **Connected App Name**: SentinelFlow
   - **API Name**: SentinelFlow
   - **Contact Email**: your-email@example.com
5. Enable OAuth Settings:
   - Check `Enable OAuth Settings`
   - **Callback URL**: `http://localhost:3000/auth/callback`
   - **Selected OAuth Scopes**:
     - Full Access (full)
     - Perform requests on your behalf at any time (refresh_token, offline_access)
6. Save the Connected App
7. Copy **Consumer Key** and **Consumer Secret** to your `.env` file:
   ```
   SALESFORCE_CLIENT_ID=your_consumer_key
   SALESFORCE_CLIENT_SECRET=your_consumer_secret
   ```

### 3. Deploy Metadata

```bash
sf project deploy start -d force-app -o sentinelFlow-dev-edition
```

### 4. Create Portal User (Optional)

For Experience Cloud portal access:

```bash
sf apex run --file scripts/apex/createPortalLoginUser.apex --target-org sentinelFlow-dev-edition
```

## Environment Configuration

### Required Environment Variables

```bash
# Application
NODE_ENV=development
APP_ENV=local
PORT=3000

# Salesforce
SALESFORCE_INSTANCE_URL=https://login.salesforce.com
SALESFORCE_ORG_ALIAS=sentinelFlow-dev-edition
SALESFORCE_CLIENT_ID=your_client_id
SALESFORCE_CLIENT_SECRET=your_client_secret
SALESFORCE_USERNAME=your_username
SALESFORCE_PASSWORD=your_password
SALESFORCE_SECURITY_TOKEN=your_security_token

# Session
SESSION_SECRET=your-secret-key-change-this-in-production
```

### Optional Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/sentinelflow

# Queue
REDIS_URL=redis://localhost:6379

# Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
EMAIL_ALERTS_ENABLED=true

# Stripe (for billing)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

See `.env.example` for a complete list of all available environment variables.

## Running the Application

### Development Mode

```bash
npm run dev
```

This starts the server with auto-reload using nodemon.

### Production Mode

```bash
npm start
```

### Access the Application

- **Main Application**: http://localhost:3000
- **Dashboard**: http://localhost:3000/dashboard
- **API Health Check**: http://localhost:3000/health
- **API Documentation**: http://localhost:3000/api

## Verification Steps

### 1. Check Health Endpoint

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "ok",
  "platform": "SentinelFlow",
  "phase": "phase-1-foundation",
  "readiness": { ... },
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 123.456
}
```

### 2. Check System Context

```bash
curl http://localhost:3000/api/system/context
```

Expected response with system configuration details.

### 3. Verify Dashboard

1. Open http://localhost:3000/dashboard in your browser
2. Verify that the dashboard loads correctly
3. Check that sample data is displayed
4. Test navigation between pages

### 4. Verify Salesforce Connection

```bash
sf org display -o sentinelFlow-dev-edition
```

Should display your org details.

## Troubleshooting

### Common Issues

#### Port Already in Use

If you see "Port 3000 is already in use":

```bash
# Find process using port 3000
lsof -i :3000  # macOS/Linux
netstat -ano | findstr :3000  # Windows

# Kill the process or change PORT in .env
PORT=3001 npm run dev
```

#### Salesforce Authentication Failed

- Verify your credentials in `.env`
- Check that the Connected App is properly configured
- Ensure your security token is correct
- Try re-authenticating: `sf org login web -a sentinelFlow-dev-edition`

#### Database Connection Failed

- Verify PostgreSQL is running
- Check DATABASE_URL in `.env`
- Ensure database exists: `createdb sentinelflow`
- Check connection permissions

#### Module Not Found Errors

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### Permission Errors

- Check file permissions
- On Unix/Linux/Mac: `chmod +x scripts/*.sh`
- On Windows: Run terminal as Administrator

### Getting Help

- Check the [troubleshooting guide](portal-login-troubleshooting.md)
- Review [architecture documentation](architecture.md)
- Check existing [GitHub Issues](https://github.com/your-username/SEOMP/issues)
- Create a new issue with details about your problem

## Production Deployment

### Pre-Deployment Checklist

- [ ] Update environment variables for production
- [ ] Set NODE_ENV=production
- [ ] Change SESSION_SECRET to a strong random value
- [ ] Configure production DATABASE_URL
- [ ] Set up production Redis instance
- [ ] Configure ALLOWED_ORIGINS
- [ ] Enable HTTPS
- [ ] Set up monitoring and logging
- [ ] Configure backup strategy
- [ ] Review and update security settings

### Deployment Options

#### Heroku

```bash
# Install Heroku CLI
npm install -g heroku

# Login
heroku login

# Create app
heroku create your-app-name

# Set environment variables
heroku config:set NODE_ENV=production
heroku config:set SESSION_SECRET=your-secret-key
# ... set other variables

# Deploy
git push heroku main
```

#### Docker

```bash
# Build image
docker build -t sentinelflow .

# Run container
docker run -p 3000:3000 --env-file .env sentinelflow
```

#### AWS/GCP/Azure

Follow your cloud provider's documentation for deploying Node.js applications.

### Post-Deployment Verification

1. Check health endpoint: `https://your-domain.com/health`
2. Verify system context: `https://your-domain.com/api/system/context`
3. Test authentication flow
4. Verify database connections
5. Check logging and monitoring
6. Test key user flows

## Next Steps

- Read the [API documentation](api.md)
- Review [architecture documentation](architecture.md)
- Check [contributing guidelines](../CONTRIBUTING.md)
- Explore the [product design](sentinelflow-product-design.md)

## Additional Resources

- [Node.js Documentation](https://nodejs.org/docs/)
- [Salesforce Developer Documentation](https://developer.salesforce.com/docs)
- [Express.js Documentation](https://expressjs.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
