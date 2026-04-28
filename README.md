# salesforce-ops-monitoring-platform

Real-time, event-driven monitoring and administration system designed for enterprise Salesforce environments. It provides visibility into system health, automates administrative processes, and enables proactive incident management by integrating Salesforce with a Node.js middleware deployed on Heroku.

## SEOMP Phase 1 Foundation

This repository now provides the Phase 1 foundation for the Salesforce Enterprise Operations Monitoring Platform (SEOMP). The goal of this phase is to establish architecture, environment scaffolding, platform configuration, and readiness checks before implementing live event processing.

## Phase 1 Outcomes

- SEOMP platform configuration baseline
- Environment template for local and hosted setups
- System context and readiness endpoints
- Data model and architecture documentation
- Terraform scaffold for infrastructure planning
- Existing Salesforce integration modules preserved for later phases

## Developer Org Fit

This setup is tuned for a single Salesforce Developer Edition org rather than a full enterprise multi-org landscape. That means:

- one Connected App for OAuth
- one org alias in local configuration
- local Node.js runtime instead of requiring Heroku on day one
- Redis and PostgreSQL remain optional local dependencies until Phase 2 is implemented

The project still keeps the SEOMP enterprise shape, but the setup path is intentionally lightweight so you can build and demo it from a Developer Org account.

## Repository Structure

```text
.
├── config/
│   └── project-scratch-def.json
├── docs/
│   ├── architecture.md
│   ├── data-model.md
│   └── phase-1-foundation.md
├── force-app/
│   └── main/
│       └── default/
├── manifest/
│   └── package.xml
├── infrastructure/
│   └── terraform/
├── src/
│   ├── app.js
│   ├── config/
│   │   └── seomp.js
│   ├── controllers/
│   │   ├── analyticsController.js
│   │   └── systemController.js
│   ├── middleware/
│   │   ├── errorHandler.js
│   │   └── logger.js
│   ├── modules/
│   ├── routes/
│   │   ├── analytics.js
│   │   └── system.js
│   └── services/
├── .env.example
├── SEOMP_Documentation.docx
├── SEOMP_Implementation_Plan.docx
└── README.md
```

## Salesforce Project Layout

This repository now includes a standard Salesforce DX source structure alongside the Node.js middleware:

- `force-app/main/default/`: Salesforce metadata source
- `manifest/package.xml`: retrieval and deployment manifest
- `config/project-scratch-def.json`: scratch org definition template
- `sfdx-project.json`: Salesforce DX project configuration

Use `src/` for the Express-based SEOMP middleware and `force-app/` for Salesforce metadata such as objects, Apex, LWCs, permission sets, and layouts.

## Prerequisites

- Node.js 16 or higher
- npm
- Salesforce org with a Connected App
- PostgreSQL instance for future persistence work
- Redis or Kafka target planned for Phase 2

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Create your local environment file:

   ```bash
   cp .env.example .env
   ```

3. Populate the Salesforce, database, and session values in `.env`.

4. Start the application:

   ```bash
   npm run dev
   ```

## Phase 1 Endpoints

- `GET /health`: platform health plus Phase 1 readiness state
- `GET /api/system/context`: SEOMP platform, environment, and service configuration summary
- `GET /api/system/readiness`: missing required environment variables and workstream readiness

## Documentation

- [Architecture](docs/architecture.md)
- [Data Model](docs/data-model.md)
- [Phase 1 Summary](docs/phase-1-foundation.md)
- [Developer Org Setup](docs/developer-org-setup.md)
- [Dashboard Handoff](docs/dashboard-handoff.md)
- [Experience Cloud Plan](docs/experience-cloud-plan.md)
- [Experience Cloud Build Checklist](docs/experience-cloud-build-checklist.md)

## GitHub Sync

Once a GitHub remote is attached, you can sync all tracked changes with:

```bash
bash scripts/sync-github.sh "your commit message"
```

That script stages the repo, creates a commit when needed, and pushes the current branch to `origin`. It is intentionally manual so you stay in control of what gets published.

## Next Phase

Phase 2 should add:

- Streaming API subscription via CometD
- Redis or Kafka event buffering
- PostgreSQL persistence for incidents and logs
- SEOMP incident APIs and monitoring workflows
