# SentinelFlow AppExchange Readiness Checklist

> **Last updated**: 2026-05-12
> **AppExchange version**: 2.6.1
> **Published by**: Tomcodex
> **Target listing category**: Salesforce DevOps · IT Operations · Security · AI Operations
> **Tagline**: Secure. Learn. Heal. Scale.

---

## 1. Current App Metadata Status

- Lightning app: `SentinelFlow_Console`
- Label: `SentinelFlow Console`
- AppExchange version: `2.6.1`
- Published by: `Tomcodex`
- Description: `Salesforce's Autonomous Immune System: secure, learn, heal, and scale with AI-powered operational intelligence.`
- Navigation now prioritizes current SentinelFlow objects:
  - `SF_Incident__c`
  - `SF_Incident_Memory__c`
  - `SF_Prediction_Risk__c`
  - `SF_Healing_Runbook__c`
  - `Integration_Log__c`

### Verified Astrosoft Deployment

| Attribute | Value |
|---|---|
| Target org | `astrosoft2-dev-ed.develop.lightning.force.com` |
| Deploy ID | `0AfdL00000aKZ89SAG` |
| Components deployed | 138 / 138 |
| Apex tests passed | 36 / 36 |
| Test mode | `RunSpecifiedTests` |

### Smoke Test Confirmation

```text
Integration_Log__c (Failed) → IntegrationLogTrigger → SentinelFlow_Incident__e → SentinelFlowIncidentTrigger → SF_Incident__c
```

- Created incident: `INC-20260511-0001`
- Severity: `P1_High`
- Source: `Stripe Gateway Smoke Test`

---

## 2. Listing Source

The AppExchange listing draft is maintained in:

- `docs/sentinelflow-appexchange-listing.md`
- `docs/sentinelflow-security-review-packet.md`

---

## 3. Package Component Inventory

### Custom Objects (6)

| API Name | Type | Purpose |
|---|---|---|
| `SF_Incident__c` | Data | Core incident records |
| `SF_Incident_Memory__c` | Data | Operational memory for past incidents |
| `SF_Prediction_Risk__c` | Data | Prediction risk scoring records |
| `SF_Healing_Runbook__c` | Data | Auto-heal runbook definitions |
| `Integration_Log__c` | Data | Integration telemetry source |
| `Flow_Fault_Log__c` | Data | Flow fault telemetry source |

### Custom Metadata Types (3)

| API Name | Records | Purpose |
|---|---|---|
| `SF_Detection_Threshold__mdt` | `API_Latency`, `Integration_Errors` | Configurable detection thresholds |
| `SF_Healing_Rule__mdt` | `OAuth_Refresh`, `Pause_Batch`, `Requeue_Job`, `Retry_With_Backoff` | Auto-heal rule definitions |
| `SF_Integration_Config__mdt` | `HubSpot_Sync`, `Stripe_Gateway` | Integration configuration |

### Platform Events (3)

| API Name | Purpose |
|---|---|
| `SentinelFlow_Incident__e` | Incident detection event |
| `SentinelFlow_Alert__e` | Alert notification event |
| `SentinelFlow_Heal_Command__e` | Auto-heal orchestration command |

### Apex Classes (19 classes, 10 test classes)

| Class | Category | Test Class |
|---|---|---|
| `AutoHealOrchestrator` | Auto-heal | `AutoHealOrchestratorTest` |
| `IncidentClassificationQueueable` | AI classification | `IncidentClassificationQueueableTest` |
| `MemoryIndexQueueable` | Memory engine | — ⚠️ |
| `PredictionEngineBatch` | Prediction | `PredictionEngineBatchTest` |
| `PredictionEngineScheduler` | Prediction | `PredictionEngineSchedulerTest` |
| `SentinelFlowEventPublisher` | Event bus | `SentinelFlowEventPublisherTest` |
| `SentinelFlowIncidentHandler` | Incident mgmt | `SentinelFlowIncidentHandlerTest` |
| `SentinelFlowLogger` | Logging | `SentinelFlowLoggerTest` |
| `SentinelFlowNotifier` | Notifications | `SentinelFlowNotifierTest` |

### Triggers (3)

| Trigger | Object | Test Class |
|---|---|---|
| `IntegrationLogTrigger` | `Integration_Log__c` | `IntegrationLogTriggerTest` |
| `FlowFaultTrigger` | `Flow_Fault_Log__c` | `FlowFaultTriggerTest` |
| `SentinelFlowIncidentTrigger` | `SentinelFlow_Incident__e` | — (covered by handler test) |

### Permission Sets (2)

| Permission Set | Label | Scope |
|---|---|---|
| `SentinelFlow_Admin` | SentinelFlow Admin | Full CRUD on all objects + all field access |
| `SentinelFlow_Viewer` | SentinelFlow Viewer | Read-only on core objects + read field access |

### Other Metadata

- **Approval Processes**: `SF_Incident__c.High_Impact_Auto_Heal_Approval`
- **Layouts**: Custom layouts for SentinelFlow objects
- **Tabs**: Custom tabs for core objects
- **Flexi Pages**: Lightning record/app pages
- **Static Resources**: Supporting assets
- **Aura Components**: Legacy support components
- **Workflows**: Object-level workflow rules

---

## 4. Backend API Inventory

### API Server

- Stack: Express.js + TypeScript
- Location: `sentinelflow-api/`
- Health endpoint: `GET /api/health` → `{ status: "ok", version: "2.0.0", intelligenceMode: "self-evolving" }`

### Endpoints (13)

| Method | Endpoint | Service | Category |
|---|---|---|---|
| `POST` | `/api/classify` | `aiService` | AI Classification |
| `POST` | `/api/memory/index` | `memoryService` | Operational Memory |
| `POST` | `/api/memory/search` | `memoryService` | Operational Memory |
| `GET` | `/api/memory/analytics` | `memoryService` | Operational Memory |
| `POST` | `/api/runbooks/recommend` | `adaptiveRunbookService` | Runbook Intelligence |
| `POST` | `/api/predict/batch` | `aiService` | Prediction V1 |
| `POST` | `/api/predict/v2` | `predictionV2Service` | Prediction V2 |
| `POST` | `/api/learning/outcome` | `learningLoopService` | Learning Loop |
| `GET` | `/api/learning/quality` | `learningLoopService` | Learning Loop |
| `POST` | `/api/heal/oauth-refresh` | `healService` | Auto-Heal |
| `POST` | `/api/heal/retry` | `healService` | Auto-Heal |
| `POST` | `/api/heal/pause-batch` | `healService` | Auto-Heal |
| `POST` | `/api/heal/requeue-job` | `healService` | Auto-Heal |
| `POST` | `/api/reliability/simulate` | `reliabilityService` | Reliability Testing |

### Backend Services (7)

| Service | File | Purpose |
|---|---|---|
| `aiService` | `ai.service.ts` | Incident classification, batch prediction |
| `healService` | `heal.service.ts` | OAuth refresh, retry, pause, requeue |
| `memoryService` | `memory.service.ts` | Vector-based incident memory, search, analytics |
| `adaptiveRunbookService` | `adaptive-runbook.service.ts` | Runbook recommendation and confidence ranking |
| `predictionV2Service` | `prediction-v2.service.ts` | Failure probability, deployment risk, org stability |
| `learningLoopService` | `learning-loop.service.ts` | Recovery outcome learning, model quality |
| `reliabilityService` | `reliability.service.ts` | Chaos simulation suite |

### Database Schema

- Location: `sentinelflow-api/db/operational-memory.schema.sql`
- Engine: PostgreSQL / Supabase with `pgvector` + `pgcrypto`

| Table | Purpose | RLS Enabled |
|---|---|---|
| `tenant` | Org-to-tenant mapping | — |
| `incident_memory` | Incident knowledge base with vector embeddings | ✅ |
| `runbook_outcome` | Runbook execution history | ✅ |
| `prediction_observation` | Prediction accuracy tracking | ✅ |
| `reliability_simulation` | Reliability test results | ✅ |

RLS policy pattern: `tenant_id::text = current_setting('app.tenant_id', true)`

---

## 5. Dashboard Inventory

- Framework: Next.js
- Location: `sentinelflow-dashboard/`
- Auth: Salesforce SSO via NextAuth

### Dashboard V2 Panels

- Org Health Score KPI
- AI Confidence KPI
- Deployment Risk KPI
- AI Confidence and Prediction Accuracy chart
- Incident heatmap
- Autonomous Recovery Timeline
- Live AI Ops Feed (predictions, incidents, recoveries, escalations)
- Auto-Heal Success Analytics

---

## 6. Security Architecture

### Tenant Isolation

- Every backend record is scoped by Salesforce org id and mapped to a tenant id.
- Database isolation: Supabase/Postgres row-level security policies enabled on all operational memory tables.
- Salesforce callouts: all Apex-to-backend traffic uses `SentinelFlow_Backend` Named Credential.
- Memory search is partitioned by tenant before vector similarity ranking.
- Embeddings stored per tenant; no shared model training without explicit opt-in.

### Authentication & Authorization

- OAuth audit: token refresh, grant changes, and failed auth attempts emit audit logs.
- Permission model: package permission sets expose only required object, field, Apex class, and Named Credential access.
- Secrets: no secrets stored in Custom Metadata, Apex code, static resources, or dashboard bundles.

### Logging

- Incident, heal, escalation, prediction, and memory events are immutable and correlation-id based.
- Every `SF_Incident__c` record includes `Correlation_Id__c`, `Detected_At__c`, and `MTTR_Seconds__c`.

---

## 7. Multi-Tenant Isolation Review

- [x] Validate tenant id on every API request.
- [x] Reject cross-org tenant context in request payloads and query parameters even when authenticated.
- [ ] Partition memory search by tenant before vector similarity ranking.
- [ ] Store embeddings per tenant and never train shared models on customer data without explicit opt-in.
- [x] Include org id, user id, request id, and package version in request context.

---

## 8. API Rate Limit Protections

- [x] Add per-tenant request quotas for classification, prediction, memory search, and healing.
- [ ] Add circuit breakers for repeated failed heal actions.
- [ ] Cap retry queues to prevent retry storms.
- [ ] Back pressure Platform Event ingestion during spikes.
- [ ] Escalate instead of retrying when confidence falls below the configured floor.

---

## 9. Managed Package Strategy

### Namespace

- **Current state**: `sfdx-project.json` has `"namespace": ""` (empty).
- **Required action**: Register a namespace prefix (e.g., `sfnl`) in a Salesforce packaging org.
- All Apex classes, Custom Objects, Platform Events, Custom Metadata Types, and LWC must be namespaced.

### Packaging Checklist

- [ ] Register namespace prefix in packaging org.
- [ ] Update `sfdx-project.json` with namespace and package version definition.
- [ ] Namespace-qualify all Apex class references, SOQL queries, and trigger references.
- [ ] Keep admin-configurable thresholds in Custom Metadata (`SF_Detection_Threshold__mdt`, `SF_Healing_Rule__mdt`, `SF_Integration_Config__mdt`).
- [ ] Keep customer data in subscriber org objects or tenant-isolated backend tables.
- [ ] Validate metadata deployability against a clean scratch org.
- [ ] Validate metadata deployability against the packaging org.
- [ ] Verify upgrade scripts preserve incident history and runbook configuration.
- [ ] Create 2GP package version: `sf package version create`.
- [ ] Promote package version for AppExchange: `sf package version promote`.

### Approval Process Fix (Pre-Package)

- **Current state**: Approval process `High_Impact_Auto_Heal_Approval` references org-specific user `vjdev@asap.com`.
- **Required action**: Replace with a configurable queue, public group, or approver lookup field.

---

## 10. Permission Set Audit

### SentinelFlow_Admin

| Object | Create | Read | Edit | Delete | ViewAll | ModAll |
|---|---|---|---|---|---|---|
| `SF_Incident__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SF_Incident_Memory__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SF_Healing_Runbook__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SF_Prediction_Risk__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Integration_Log__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Flow_Fault_Log__c` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Field permissions: 18 fields across `SF_Incident__c`, `Integration_Log__c`, `Flow_Fault_Log__c` — all read + edit.

### SentinelFlow_Viewer

| Object | Create | Read | Edit | Delete | ViewAll | ModAll |
|---|---|---|---|---|---|---|
| `SF_Incident__c` | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `SF_Incident_Memory__c` | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `SF_Healing_Runbook__c` | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `SF_Prediction_Risk__c` | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ |

Field permissions: 7 `SF_Incident__c` fields — read-only.

### Permission Gaps to Resolve

- [x] Viewer permission set includes `Integration_Log__c` read access. `Flow_Fault_Log__c` is not present in current metadata.
- [x] Viewer permission set includes current `Integration_Log__c` field permissions. `Flow_Fault_Log__c` is not present in current metadata.
- [x] Permission sets include Apex class access grants for managed package use.
- [x] Permission sets include Platform Event access for `Integration_Health_Event__e`.
- [ ] Named Credential access for `SentinelFlow_Backend` must be completed through subscriber setup or External Credential principal access metadata; legacy `namedCredentialAccesses` is not package-valid here.
- [x] Added and extended `SentinelFlow_Operator` (create/edit incidents, trigger heals, no delete).

---

## 11. Apex Test Coverage

### Current Test Matrix

| Apex Component | Test Class | Status |
|---|---|---|
| `AutoHealOrchestrator` | `AutoHealOrchestratorTest` | ✅ Passing |
| `IncidentClassificationQueueable` | `IncidentClassificationQueueableTest` | ✅ Passing |
| `PredictionEngineBatch` | `PredictionEngineBatchTest` | ✅ Passing |
| `PredictionEngineScheduler` | `PredictionEngineSchedulerTest` | ✅ Passing |
| `SentinelFlowEventPublisher` | `SentinelFlowEventPublisherTest` | ✅ Passing |
| `SentinelFlowIncidentHandler` | `SentinelFlowIncidentHandlerTest` | ✅ Passing |
| `SentinelFlowLogger` | `SentinelFlowLoggerTest` | ✅ Passing |
| `SentinelFlowNotifier` | `SentinelFlowNotifierTest` | ✅ Passing |
| `IntegrationLogTrigger` | `IntegrationLogTriggerTest` | ✅ Passing |
| `FlowFaultTrigger` | `FlowFaultTriggerTest` | ✅ Passing |

### Coverage Gaps

- [ ] `MemoryIndexQueueable` — no dedicated test class. Must add `MemoryIndexQueueableTest`.
- [ ] Achieve ≥ 75% org-wide code coverage with namespace-qualified packaging test run.
- [ ] All test classes must pass with `RunLocalTests` in a clean packaging org.

---

## 12. SOC2-Ready Logging

### Required Event Families

- Authentication and SSO events
- OAuth token lifecycle events
- Incident detected / classified / healed / escalated events
- Runbook recommendation and selection events
- Memory indexing and search events
- Prediction generated / observed events
- Reliability simulation events
- Administrative configuration changes

### Required Event Fields

Each event must include:

| Field | Purpose |
|---|---|
| `timestamp` | Event time (UTC) |
| `tenant_id` | Subscriber org isolation |
| `actor` | User or system identity |
| `correlation_id` | End-to-end tracing |
| `source_ip` or `sf_user_context` | Origin identification |
| `severity` | Event criticality |
| `action` | What happened |
| `payload_hash` | Immutable integrity proof |

---

## 13. Security Review Submission Packet

The Salesforce AppExchange Security Review requires the following deliverables:

### Required Documents

- [ ] **Data Flow Diagram**: End-to-end data flow from Salesforce telemetry → Platform Events → backend API → Supabase → dashboard.
- [ ] **Permission Matrix**: Full mapping of permission sets to objects, fields, Apex classes, VF pages, Named Credentials, and Platform Events.
- [ ] **OAuth Flow Documentation**: Connected App configuration, token refresh lifecycle, audit trail for grant changes.
- [ ] **Logging Architecture**: SOC2 event families, immutability guarantees, retention policies, and correlation-id tracing.
- [ ] **External Endpoint Declaration**: Backend API base URL, Supabase connection, any third-party AI provider endpoints.
- [ ] **Data Classification**: PII/PHI/confidential data mapping across all custom objects and backend tables.
- [ ] **Encryption at Rest / in Transit**: TLS configuration, Supabase encryption settings, field-level encryption needs.

### Security Scan

- [ ] Run Salesforce Code Analyzer (formerly PMD) on all Apex classes.
- [ ] Run Checkmarx or equivalent SAST scan on backend TypeScript.
- [ ] Remediate all Critical and High findings.
- [ ] Document accepted Medium/Low findings with justification.

---

## 14. Pre-Submission Action Items

### Critical (Must Fix Before Submission)

| # | Item | Component | Status |
|---|---|---|---|
| 1 | Register managed package namespace | `sfdx-project.json` | ⬜ Not started |
| 2 | Replace org-specific approval process approver | `High_Impact_Auto_Heal_Approval` | ⬜ Not started |
| 3 | Add `MemoryIndexQueueableTest` | Apex test coverage | ⬜ Not started |
| 4 | Add Apex class access to permission sets | `SentinelFlow_Admin`, `SentinelFlow_Viewer`, `SentinelFlow_Operator` | ✅ Done in repo metadata |
| 5 | Add Platform Event access to permission sets | `SentinelFlow_Admin`, `SentinelFlow_Viewer`, `SentinelFlow_Operator` | ✅ Done for `Integration_Health_Event__e` |
| 6 | Add Named Credential access to permission sets | `SentinelFlow_Admin`, `SentinelFlow_Operator` | ⬜ Requires subscriber setup / External Credential metadata |
| 7 | Add Viewer access for `Integration_Log__c` and `Flow_Fault_Log__c` | `SentinelFlow_Viewer` | ✅ Done for current repo `Integration_Log__c`; `Flow_Fault_Log__c` not present in metadata |
| 8 | Add tenant context enforcement to all API endpoints | `src/app.js` | ✅ Done with `requestContext` middleware |
| 9 | Add API rate limiting middleware | `src/app.js` | ✅ Done with `rateLimit` middleware |
| 10 | Convert subscriber backend endpoint to Named Credential setup | Documentation | ⬜ Not started |
| 11 | Remove or sanitize smoke-test records before packaging | `SF_Incident__c` data | ⬜ Not started |
| 12 | Create security review data flow diagram | Documentation | ✅ Done in `docs/sentinelflow-security-review-packet.md` |

### Important (Should Fix Before Submission)

| # | Item | Component | Status |
|---|---|---|---|
| 13 | Add `SentinelFlow_Operator` permission set (create/edit, no delete) | Permission sets | ✅ Already present and extended |
| 14 | Add circuit breakers for heal action retry loops | `heal.service.ts` | ⬜ Not started |
| 15 | Add request correlation-id propagation across API calls | `src/app.js` | ✅ Done via `x-request-id` |
| 16 | Add structured error responses with error codes | `src/app.js` | ✅ Done for tenant and rate-limit guardrails |
| 17 | Add API input validation middleware | `src/app.js` | ✅ Done with `inputValidation` middleware |
| 18 | Build LWC components for in-platform visibility | `force-app/main/default/lwc` | ⬜ Not started |
| 19 | Add package install/upgrade handler Apex class | Apex | ⬜ Not started |
| 20 | Document Named Credential + External Credential setup | Post-install guide | ⬜ Not started |

### Nice to Have (Post-Launch)

| # | Item | Component | Status |
|---|---|---|---|
| 21 | Add CORS origin whitelist per tenant | `sentinelflow-api` | ⬜ Not started |
| 22 | Add webhook signature verification for inbound events | `sentinelflow-api` | ⬜ Not started |
| 23 | Add Supabase schema migration version tracking | `sentinelflow-api/db` | ⬜ Not started |
| 24 | Add package telemetry for install, upgrade, and uninstall events | Apex | ⬜ Not started |

---

## 15. Investor-Ready Architecture Overview

SentinelFlow is not a monitoring dashboard or CRM utility. It is an autonomous Salesforce operations platform that functions as an operational intelligence layer for the enterprise.

The moat is cumulative operational learning:

- Every incident becomes structured memory.
- Every recovery updates runbook confidence.
- Every failed heal reduces future automation risk.
- Every prediction can be validated against observed outcomes.
- Every tenant receives isolated intelligence while the platform architecture scales horizontally.

### Intelligence Loop

```text
Detect → Analyze → Predict → Heal → Validate → Learn → Evolve
```

### Technology Stack

| Layer | Technology |
|---|---|
| Platform | Salesforce (Apex, Platform Events, Custom Metadata) |
| Backend | Express.js + TypeScript |
| Database | Supabase (PostgreSQL + pgvector + RLS) |
| Dashboard | Next.js + NextAuth (Salesforce SSO) |
| AI | Classification, prediction, memory similarity |
| Packaging | Salesforce 2GP Managed Package |

---

## 16. Deployment Gate

All of the following must pass before AppExchange submission:

- [ ] Apex tests pass using `RunLocalTests` in packaging org.
- [ ] All Apex tests pass with namespace prefix enabled.
- [ ] Backend TypeScript build passes (`npm run build`).
- [ ] Dashboard production build passes (`npm run build`).
- [ ] Supabase schema migrations are reviewed and reversible.
- [ ] Named Credential and External Credential configuration is documented.
- [ ] Security review package contains data-flow diagram, permission matrix, OAuth flows, and logging architecture.
- [ ] Reliability simulation score is ≥ 90 at intensity level 3.
- [ ] Memory indexing succeeds for both successful and failed auto-heal paths.
- [ ] Dashboard V2 shows live prediction, recovery, escalation, and learning telemetry.
- [ ] No org-specific references remain in package metadata.
- [ ] Package version created and promoted in packaging org.
- [ ] Package installed and smoke-tested in a clean scratch org.

---

## 17. Reference Documents

| Document | Path |
|---|---|
| AppExchange listing draft | [sentinelflow-appexchange-listing.md](file:///d:/New%20folder/VJ%20SFDC/docs/sentinelflow-appexchange-listing.md) |
| Next evolution architecture | [sentinelflow-next-evolution-architecture.md](file:///d:/New%20folder/VJ%20SFDC/docs/sentinelflow-next-evolution-architecture.md) |
| Change log (2026-05-11) | [sentinelflow-change-log-2026-05-11.md](file:///d:/New%20folder/VJ%20SFDC/docs/sentinelflow-change-log-2026-05-11.md) |
| Security review packet | [sentinelflow-security-review-packet.md](file:///d:/New%20folder/VJ%20SFDC/docs/sentinelflow-security-review-packet.md) |
| Database schema | [operational-memory.schema.sql](file:///d:/New%20folder/VJ%20SFDC/sentinelflow-api/db/operational-memory.schema.sql) |
| SFDX project config | [sfdx-project.json](file:///d:/New%20folder/VJ%20SFDC/sentinelflow/sfdx-project.json) |
