# SentinelFlow Architecture Baseline

This document captures the Phase 1 target architecture for the Salesforce Enterprise Operations Monitoring Platform (SentinelFlow).

## Platform Flow

`Salesforce -> Streaming API (CometD) -> Queue (Kafka or Redis) -> Node.js Middleware -> PostgreSQL -> Experience Cloud Portal -> Alerts -> Salesforce`

## Presentation Layer

The Experience Cloud portal serves as the primary user interface for SentinelFlow, providing:

- **Command Center Dashboard**: Operational summary with real-time health metrics
- **Incident Management**: View, filter, and drill into incidents
- **Integration Monitoring**: Track failed and degraded integrations
- **Analytics**: Embedded reports and trend analysis

### Access Methods

#### For External Users
- **Username/Password Login**: Custom Experience Cloud login flow for portal users
- **Branded Experience**: Custom login page with Agentforce Copilot features panel
- **Important Note**: SSO login is not available for single Developer Edition org due to Salesforce limitation (`SAME_ORG_SSO: Cannot sign on into same org`). SSO should only be enabled after configuring a real external identity provider (SAML, OpenID Connect, or a different Salesforce org).

#### For Administrators
- **VIP Bypass**: Direct access through Salesforce Setup > All Sites
- No login screen required when accessing from within Salesforce
- Instant access to Command Center dashboard

## Portal Components

### Login Page
- Custom branded login experience
- "Sign in to your AI Operations Platform" messaging
- Salesforce SSO authentication button
- Agentforce Copilot features panel

### Command Center Dashboard
- Critical incidents card
- Open incidents card
- Failed integrations card
- Warning integrations card
- Recent escalations table
- Last refreshed status

## Phase 1 Decisions

- Salesforce remains the system of engagement and primary event source.
- The Node.js application is the control plane for ingestion, orchestration, and external APIs.
- PostgreSQL is the initial operational data store for incidents, logs, and deployment records.
- Redis is the default queue provider for the POC because it lowers setup overhead; Kafka remains a future-compatible option.
- Health and readiness endpoints are exposed from the middleware to support deployment validation.

## Initial Runtime Components

- `src/app.js`: Express runtime entry point
- `src/config/sentinelFlow.js`: SentinelFlow phase, environment, and service configuration
- `src/routes/system.js`: Phase 1 context and readiness endpoints
- `src/services/salesforceService.js`: Salesforce integration facade
- `infrastructure/terraform/`: Infrastructure-as-code scaffold for Heroku-style deployment inputs

## Phase 2 Handoff

Phase 2 should build on this baseline by adding:

- Streaming API subscription
- Queue producer and consumer services
- Incident and integration log persistence
- Dashboard metrics endpoints aligned to SentinelFlow objects
- Enhanced portal LWC components for improved UX
- Real-time data refresh in the Command Center

## Portal URL

- **Production**: https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login
- **Access**: Available via SSO for external users or VIP bypass for administrators

## Portal Login Credentials

### Portal User Account

```
Username: sentinelflow.portal.00ddl0000053505uaa@example.com
Password: SentinelFlow#2026May!
```

### User Configuration

- **Profile**: Portal profile assigned to SentinelFlow site
- **Permission Set**: `SentinelFlow_Portal_Viewer`
- **Site Status**: Published

### Important Notes

- After first login, change the password from user/account settings
- This user account is configured for Experience Cloud portal access
- The account has read access to incidents and integration logs
