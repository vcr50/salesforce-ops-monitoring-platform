# SentinelFlow + Zentom AI

## The Salesforce command center for resilient operations.

<p align="center">
  <a href="https://zread.ai/vcr50/salesforce-ops-monitoring-platform" target="_blank">
    <img src="https://img.shields.io/badge/Ask_Zread-Repository_Intelligence-00b0aa?style=for-the-badge&labelColor=000000" alt="Ask Zread" />
  </a>
</p>

SentinelFlow is an enterprise operations platform for Salesforce teams that need to see incidents clearly, understand risk quickly, and act with confidence.

It brings monitoring, prediction, approvals, governed recovery, audit evidence, and executive reporting into one Salesforce-native experience.

Built by **TomCodeX Inc.**  
Powered by **Zentom AI**.

---

## A New Way to Run Salesforce Operations

Every enterprise runs on invisible dependencies: integrations, Flows, APIs, batch jobs, webhooks, approvals, queues, and background processes.

When one of them fails, the first problem is rarely the failure itself.

The real problem is the silence.

Teams lose time asking:

- What happened?
- Who is impacted?
- Is this critical?
- What should we do next?
- Can this be safely recovered?
- Who approved the action?
- Where is the audit evidence?

SentinelFlow turns that uncertainty into a guided operational workflow.

It does not just show an alert.  
It shows the incident, the context, the risk, the recommended action, the approval path, and the evidence trail.

---

## Product Release

**SentinelFlow + Zentom AI v1.2.0** is the enterprise-stable release line.

| Area | Status |
| --- | --- |
| Product release | v1.2.0 |
| Production readiness | Released, monitored, and validated |
| Security posture | Security-reviewed and compliance-documented |
| Adoption posture | Customer success and adoption reviewed |
| AppExchange preparation | Listing assets in progress |
| Packaging | Managed 2GP path blocked pending namespace setup |

The product is ready for non-packaging AppExchange preparation. Managed package creation remains blocked until the namespace and Managed 2GP setup are resolved.

---

## What It Feels Like

Open SentinelFlow and you are not dropped into a wall of logs.

You see a command center.

Critical incidents. Active risk. System health. Approval queues. Integration status. Executive-ready operational signals.

When Zentom AI detects risk, it explains the warning in plain language. When an action is sensitive, Guardian Gate requires human approval. When recovery is safe and governed, SentinelFlow prepares the path and records the evidence.

This is operations with judgment built in.

---

## The Experience

### Command Center

A premium Salesforce-native interface for daily operations:

- Live incident visibility
- KPI cards for active, critical, resolved, and total incidents
- Light and dark mode support
- Integration health monitoring
- Search, filters, refresh, export, and simulation workflows
- Executive-facing summaries without leaving Salesforce

### Zentom AI

The intelligence layer behind SentinelFlow:

- Predicts emerging operational risk
- Scores incident severity
- Explains warning signals
- Recommends next actions
- Prepares operator context
- Supports future conversational Copilot workflows

### Guardian Gate

The control layer that keeps recovery safe:

- Human approval for high-risk actions
- Approval and rejection workflows
- Review queues for operators
- Policy-based action gating
- No approval bypass posture

### Governed Auto-Heal

Safe recovery paths for known operational issues:

- Create cases
- Create tasks
- Send notifications
- Retry safe integrations
- Update SentinelFlow statuses
- Recommend runbooks

High-risk actions require human approval. SentinelFlow is designed for governed operations, not unrestricted autonomous critical remediation.

### Compliance Evidence

Every meaningful action creates an operational trail:

- Audit logs
- Approval evidence
- Failure and rollback records
- Compliance-ready summaries
- Executive reports
- Security review support

---

## Why It Matters

Salesforce operations are now business operations.

An integration failure is not only a technical issue. It can delay revenue, block support, interrupt fulfillment, slow finance, or create compliance exposure.

SentinelFlow gives teams one place to see the operational truth and act from it.

The platform is designed around three principles:

1. **Clarity before action**  
   Operators should understand risk before they execute.

2. **Governance before automation**  
   Sensitive actions should be reviewed, approved, and auditable.

3. **Evidence after every decision**  
   Every incident should leave behind a record the business can trust.

---

## Value Language

SentinelFlow uses conservative, compliant value wording.

Use:

- Estimated cost savings
- Estimated MTTR reduction
- Estimated operational value
- Governed Auto-Heal
- Human approval required for high-risk actions

Avoid:

- Guaranteed ROI
- Guaranteed savings
- Fully autonomous critical remediation
- Approval bypass
- Unrestricted auto-healing

All value outcomes depend on customer configuration, baseline metrics, data volume, operating process, and approval policy.

---

## Product Tiers

| Tier | Designed for | Includes |
| --- | --- | --- |
| Starter | Teams that need visibility | Monitoring, dashboards, incident visibility, audit logs |
| Professional | Teams that need prediction and governed response | Zentom AI prediction engine, explainable warning cards, Guardian Gate approvals |
| Enterprise | Regulated and high-volume teams | Governed Auto-Heal, compliance evidence, cost savings analytics, executive reports |

A guided free trial is recommended for sandbox, Trialforce, or controlled evaluation environments. Enterprise pilots can use customer baseline data to measure estimated MTTR reduction, estimated cost savings, and estimated operational value.

---

## Architecture

SentinelFlow is Salesforce-native at the center, with optional middleware for external services and local previews.

```text
Salesforce
  Lightning Web Components
  Apex services
  Custom objects
  Permission sets
  Audit and compliance records

Zentom AI
  Prediction engine
  Explainable warnings
  Operator recommendations
  Copilot preview workflows

Governance Layer
  Guardian Gate approvals
  Human review
  Safe recovery boundaries
  Audit evidence

Node.js Middleware
  Express API
  Local dashboard preview
  Auth and sync routes
  Billing and integration services
```

Operational flow:

```text
Telemetry signal
  -> Incident visibility
  -> Zentom AI prediction
  -> Explainable warning
  -> Guardian Gate evaluation
  -> Human approval when required
  -> Governed action
  -> Audit evidence
  -> Executive reporting
```

---

## Technology

| Layer | Stack |
| --- | --- |
| Salesforce UI | Lightning Web Components |
| Salesforce logic | Apex, SOQL, custom metadata, custom objects |
| Operations UX | Command Center, Incident Operations, Approvals, Integrations, Settings |
| AI layer | Zentom AI prediction and recommendation workflows |
| Middleware | Node.js, Express |
| Testing | Apex tests, Jest, Salesforce CLI validation |
| Deployment | Salesforce CLI and metadata deployments |

---

## Quick Start

Clone and run the local preview:

```bash
git clone https://github.com/vcr50/salesforce-ops-monitoring-platform.git
cd salesforce-ops-monitoring-platform
npm install
cp .env.example .env
npm run dev
```

Local server:

```text
http://localhost:3000
```

Dashboard preview:

```text
http://localhost:3000/dashboard/index.html
```

The local preview can run with mock data. Live Salesforce integration requires org authentication and environment configuration.

---

## Salesforce Deployment

Authenticate:

```bash
sf org login web -a my-org
```

Deploy:

```bash
sf project deploy start --source-dir force-app --target-org my-org --test-level RunLocalTests
```

Open:

```bash
sf org open --target-org my-org
```

---

## Documentation

| Document | Description |
| --- | --- |
| [Release Notes](docs/v1.2.0-release-notes.md) | v1.2.0 product release summary |
| [AppExchange Product Description](docs/v1.2.0-appexchange-product-description.md) | Listing copy and value positioning |
| [Pricing / Trial Strategy](docs/v1.2.0-appexchange-pricing-trial-strategy.md) | Tiering, pilot, trial, and compliant wording |
| [Security Review Checklist](docs/v1.2.0-security-review-submission-checklist.md) | AppExchange security review preparation |
| [Compliance Evidence Pack](docs/v1.2.0-compliance-evidence-pack.md) | Enterprise compliance evidence |
| [Production Deployment Runbook](docs/v1.2.0-production-deployment-runbook.md) | Release deployment process |
| [Post-Install Guide](docs/sentinelflow-post-install-guide.md) | Customer setup guidance |
| [Architecture](docs/architecture.md) | System architecture overview |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Support and debugging guide |

---

## Repository Map

```text
force-app/main/default/
  classes/          Apex controllers, services, tests
  lwc/              Lightning Web Components
  objects/          Salesforce object metadata
  permissionsets/   Access control
  staticresources/  Brand and UI assets

src/
  app.js            Express entry point
  routes/           API routes
  services/         Middleware services
  dashboard/        Local preview dashboard

docs/               Product, release, security, and AppExchange docs
manifest/           Salesforce package manifests
scripts/            Utility scripts
tests/              Jest tests
website/            Marketing website
website-next/       Next.js website/dashboard work
```

---

## Roadmap

Completed:

- Predictive warning console
- Explainable warning cards
- Guardian Gate approval flows
- Governed Auto-Heal safety boundaries
- Cost savings analytics
- Compliance evidence pack
- Production release validation
- AppExchange listing preparation assets

In progress:

- AppExchange listing refinement
- Premium UI polish
- Expanded Zentom Copilot preview workflows

Blocked:

- Managed 2GP package candidate until namespace and Managed 2GP setup are resolved

---

## Company

SentinelFlow + Zentom AI is built by **TomCodeX Inc.**

The mission is simple:

Give Salesforce operations teams the clarity to see what is happening, the intelligence to understand what matters, and the governance to act safely.

---

## License

MIT License.

Copyright 2026 TomCodeX Inc. All rights reserved.
