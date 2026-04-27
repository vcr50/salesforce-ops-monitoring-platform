# SEOMP Architecture Baseline

This document captures the Phase 1 target architecture for the Salesforce Enterprise Operations Monitoring Platform (SEOMP).

## Platform Flow

`Salesforce -> Streaming API (CometD) -> Queue (Kafka or Redis) -> Node.js Middleware -> PostgreSQL -> Dashboard -> Alerts -> Salesforce`

## Phase 1 Decisions

- Salesforce remains the system of engagement and primary event source.
- The Node.js application is the control plane for ingestion, orchestration, and external APIs.
- PostgreSQL is the initial operational data store for incidents, logs, and deployment records.
- Redis is the default queue provider for the POC because it lowers setup overhead; Kafka remains a future-compatible option.
- Health and readiness endpoints are exposed from the middleware to support deployment validation.

## Initial Runtime Components

- `src/app.js`: Express runtime entry point
- `src/config/seomp.js`: SEOMP phase, environment, and service configuration
- `src/routes/system.js`: Phase 1 context and readiness endpoints
- `src/services/salesforceService.js`: Salesforce integration facade
- `infrastructure/terraform/`: Infrastructure-as-code scaffold for Heroku-style deployment inputs

## Phase 2 Handoff

Phase 2 should build on this baseline by adding:

- Streaming API subscription
- Queue producer and consumer services
- Incident and integration log persistence
- Dashboard metrics endpoints aligned to SEOMP objects
