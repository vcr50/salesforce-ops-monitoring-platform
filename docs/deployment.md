# SentinelFlow Deployment Guide

This guide covers deploying SentinelFlow to production environments.

## Table of Contents

- [Overview](#overview)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Options](#deployment-options)
- [Environment Configuration](#environment-configuration)
- [Deployment Strategies](#deployment-strategies)
- [Post-Deployment](#post-deployment)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Rollback Procedures](#rollback-procedures)

## Overview

SentinelFlow can be deployed to various platforms including:
- Heroku
- AWS
- Google Cloud Platform (GCP)
- Microsoft Azure
- Docker/Kubernetes
- Traditional VPS

## Pre-Deployment Checklist

Before deploying to production, ensure:

### Security

- [ ] Change all default passwords and secrets
- [ ] Set strong SESSION_SECRET
- [ ] Configure proper SSL/TLS certificates
- [ ] Enable HTTPS
- [ ] Review and update CORS settings
- [ ] Configure firewall rules
- [ ] Set up proper authentication

### Configuration

- [ ] Set NODE_ENV=production
- [ ] Configure production DATABASE_URL
- [ ] Set up production Redis instance
- [ ] Configure ALLOWED_ORIGINS
- [ ] Set up proper logging
- [ ] Configure email/Slack notifications
- [ ] Set up backup strategy

### Testing

- [ ] Run all tests: `npm test`
- [ ] Verify test coverage meets requirements
- [ ] Test in staging environment
- [ ] Perform load testing
- [ ] Test authentication flow
- [ ] Verify Salesforce integration
- [ ] Test all critical user flows

### Documentation

- [ ] Update CHANGELOG.md
- [ ] Review API documentation
- [ ] Update deployment documentation
- [ ] Document any custom configurations
- [ ] Prepare runbooks for operations

## Deployment Options

### Heroku

#### Prerequisites

- Heroku account
- Heroku CLI installed
- Git repository

#### Steps

1. **Install Heroku CLI**:
   ```bash
   npm install -g heroku
   ```

2. **Login to Heroku**:
   ```bash
   heroku login
   ```

3. **Create app**:
   ```bash
   heroku create your-app-name
   ```

4. **Set environment variables**:
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set SESSION_SECRET=your-secret-key
   heroku config:set DATABASE_URL=your-database-url
   heroku config:set REDIS_URL=your-redis-url
   heroku config:set SALESFORCE_CLIENT_ID=your-client-id
   heroku config:set SALESFORCE_CLIENT_SECRET=your-client-secret
   ```

5. **Add add-ons** (optional):
   ```bash
   heroku addons:create heroku-postgresql:standard-0
   heroku addons:create heroku-redis:premium-0
   ```

6. **Deploy**:
   ```bash
   git push heroku main
   ```

7. **Open app**:
   ```bash
   heroku open
   ```

#### Scaling

```bash
# Scale to 2 dynos
heroku ps:scale web=2

# Scale worker processes
heroku ps:scale worker=1
```

### Docker

#### Dockerfile

```dockerfile
FROM node:16-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Start application
CMD ["node", "src/app.js"]
```

#### Build and Run

```bash
# Build image
docker build -t sentinelflow .

# Run container
docker run -d   --name sentinelflow   -p 3000:3000   --env-file .env   sentinelflow
```

#### Docker Compose

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://db:5432/sentinelflow
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:14-alpine
    environment:
      - POSTGRES_DB=sentinelflow
      - POSTGRES_USER=sentinel
      - POSTGRES_PASSWORD=your-password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

Run with:
```bash
docker-compose up -d
```

### AWS

#### Using Elastic Beanstalk

1. **Install EB CLI**:
   ```bash
   pip install awsebcli
   ```

2. **Initialize**:
   ```bash
   eb init -p node.js your-app-name
   ```

3. **Create environment**:
   ```bash
   eb create production-env
   ```

4. **Deploy**:
   ```bash
   eb deploy
   ```

#### Using ECS/Fargate

1. Create ECR repository
2. Build and push Docker image
3. Create ECS task definition
4. Create ECS service
5. Configure load balancer
6. Deploy

### GCP

#### Using App Engine

1. **Create app.yaml**:
   ```yaml
   runtime: nodejs16
   env: flex

   env_variables:
     NODE_ENV: production
     PORT: 8080

   manual_scaling:
     instances: 1
   ```

2. **Deploy**:
   ```bash
   gcloud app deploy
   ```

#### Using Cloud Run

1. **Build and push image**:
   ```bash
   gcloud builds submit --tag gcr.io/PROJECT_ID/sentinelflow
   ```

2. **Deploy**:
   ```bash
   gcloud run deploy sentinelflow      --image gcr.io/PROJECT_ID/sentinelflow      --platform managed      --region REGION
   ```

### Azure

#### Using App Service

1. **Create resource group**:
   ```bash
   az group create --name myResourceGroup --location eastus
   ```

2. **Create app service plan**:
   ```bash
   az appservice plan create      --name myAppServicePlan      --resource-group myResourceGroup      --sku B1
   ```

3. **Create web app**:
   ```bash
   az webapp create      --name myAppName      --resource-group myResourceGroup      --plan myAppServicePlan
   ```

4. **Deploy**:
   ```bash
   az webapp up      --name myAppName      --resource-group myResourceGroup
   ```

## Environment Configuration

### Required Production Variables

```bash
NODE_ENV=production
APP_ENV=production
PORT=3000
SESSION_SECRET=strong-random-secret-here
DATABASE_URL=postgresql://user:pass@host:5432/db
REDIS_URL=redis://host:6379
SALESFORCE_CLIENT_ID=your-client-id
SALESFORCE_CLIENT_SECRET=your-client-secret
SALESFORCE_USERNAME=your-username
SALESFORCE_PASSWORD=your-password
SALESFORCE_SECURITY_TOKEN=your-token
ALLOWED_ORIGINS=https://your-domain.com
```

### Optional Production Variables

```bash
LOG_LEVEL=info
ENABLE_ANALYTICS=true
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
EMAIL_ALERTS_ENABLED=true
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Deployment Strategies

### Blue-Green Deployment

1. Deploy new version to staging environment
2. Run smoke tests
3. Switch traffic to new version
4. Monitor for issues
5. Rollback if needed

### Canary Deployment

1. Deploy new version to small subset of users
2. Monitor metrics and errors
3. Gradually increase traffic
4. Full rollout if successful
5. Rollback if issues detected

### Rolling Deployment

1. Update instances one at a time
2. Ensure minimum capacity maintained
3. Monitor health checks
4. Continue until all updated

## Post-Deployment

### Verification Steps

1. **Health Check**:
   ```bash
   curl https://your-domain.com/health
   ```

2. **System Context**:
   ```bash
   curl https://your-domain.com/api/system/context
   ```

3. **Test Authentication**:
   - Login flow
   - Session management
   - Token refresh

4. **Test Key Features**:
   - Incident creation
   - AI analysis
   - Auto-healing
   - Dashboard loading

5. **Check Logs**:
   - Application logs
   - Error logs
   - Performance metrics

### Monitoring Setup

1. **Application Monitoring**:
   - Set up APM (New Relic, Datadog, etc.)
   - Configure error tracking (Sentry, etc.)
   - Set up log aggregation (ELK, CloudWatch, etc.)

2. **Infrastructure Monitoring**:
   - CPU, memory, disk usage
   - Network metrics
   - Database performance

3. **Business Metrics**:
   - Incident volume
   - Response times
   - User activity

### Alert Configuration

Set up alerts for:
- Application errors
- High error rates
- Slow response times
- Database connection issues
- Salesforce API failures
- Queue processing delays

## Monitoring and Maintenance

### Daily Tasks

- Review error logs
- Check system health
- Monitor key metrics
- Review incident volume

### Weekly Tasks

- Review performance trends
- Check security logs
- Update dependencies
- Review backup status

### Monthly Tasks

- Review and optimize queries
- Update documentation
- Review and update runbooks
- Capacity planning

### Regular Maintenance

- **Dependency Updates**:
  ```bash
  npm audit
  npm update
  ```

- **Database Maintenance**:
  - Run VACUUM ANALYZE
  - Update statistics
  - Review indexes

- **Log Rotation**:
  - Configure log rotation
  - Archive old logs
  - Monitor log storage

## Rollback Procedures

### Immediate Rollback

If critical issues are detected:

1. **Stop new deployments**
2. **Revert to previous version**:
   ```bash
   # Heroku
   heroku rollback

   # Docker
   docker stop sentinelflow
   docker run -d --name sentinelflow your-previous-image

   # Git
   git revert HEAD
   git push
   ```

3. **Verify system health**
4. **Communicate with stakeholders**
5. **Investigate root cause**

### Database Rollback

If database changes cause issues:

1. **Stop application**
2. **Restore from backup**:
   ```bash
   # PostgreSQL
   psql -U username -d dbname < backup.sql
   ```
3. **Verify data integrity**
4. **Restart application**
5. **Monitor for issues**

### Salesforce Metadata Rollback

If Salesforce deployment fails:

1. **Identify failed components**
2. **Retrieve previous version**:
   ```bash
   sf project retrieve start --metadata "CustomObject:Incident__c"      --target-org production-org
   ```
3. **Deploy previous version**:
   ```bash
   sf project deploy start --source-dir force-app      --target-org production-org
   ```

## Disaster Recovery

### Backup Strategy

1. **Database Backups**:
   - Daily automated backups
   - Weekly full backups
   - Point-in-time recovery enabled
   - Store backups in multiple locations

2. **Configuration Backups**:
   - Environment variables
   - Configuration files
   - Infrastructure as code

3. **Salesforce Data**:
   - Weekly data exports
   - Metadata backups
   - Sandbox refresh strategy

### Recovery Procedures

1. **Assess impact and scope**
2. **Notify stakeholders**
3. **Initiate recovery from backups**
4. **Verify data integrity**
5. **Restore services**
6. **Monitor for issues**
7. **Document lessons learned**

## Additional Resources

- [Heroku Deployment Guide](https://devcenter.heroku.com/articles/deploying-nodejs)
- [AWS Deployment Guide](https://docs.aws.amazon.com/)
- [GCP Deployment Guide](https://cloud.google.com/docs)
- [Azure Deployment Guide](https://docs.microsoft.com/azure/)
- [Docker Documentation](https://docs.docker.com/)
