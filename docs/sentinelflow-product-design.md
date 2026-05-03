# SentinelFlow — Enterprise AI Operations Platform
### Product Design Document · Tomcodex · v1.0

---

## 1. Product Vision

> **"From signal to action — autonomously."**

SentinelFlow transforms traditional Salesforce monitoring into an intelligent, self-healing operations platform. It doesn't just detect failures — it understands them, ranks their business impact, and resolves them autonomously using Agentforce AI.

**Target Users**
| Persona | Surface | Primary Need |
|---|---|---|
| Operations Engineer | Experience Cloud Portal | Real-time incident response |
| Business Stakeholder | Impact Panel | Revenue risk awareness |
| Support Lead | Incident Queue | SLA compliance |
| CTO / VP Eng | Executive Dashboard | System-wide health |

---

## 2. System Architecture (Layered)

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 5 — PRESENTATION                                 │
│  Experience Cloud Portal · LWC Components · Dark UI     │
├─────────────────────────────────────────────────────────┤
│  LAYER 4 — AI DECISION ENGINE                           │
│  Agentforce · Root Cause Analysis · Impact Scoring      │
├─────────────────────────────────────────────────────────┤
│  LAYER 3 — AUTOMATION & ORCHESTRATION                   │
│  Salesforce Flows · Apex Controllers · Self-Heal Engine │
├─────────────────────────────────────────────────────────┤
│  LAYER 2 — EVENT & DATA BUS                             │
│  Platform Events · Streaming API · Pub/Sub API          │
├─────────────────────────────────────────────────────────┤
│  LAYER 1 — DATA FOUNDATION                              │
│  Custom Objects · SOQL · External APIs · PostgreSQL     │
└─────────────────────────────────────────────────────────┘
```

### Layer Details

**Layer 1 — Data Foundation**
- Custom objects: `Incident__c`, `Integration_Log__c`, `SLA_Policy__c`, `Environment__c`, `Deployment_Record__c`, `Audit_Trail__c`
- External API connectors via Named Credentials
- PostgreSQL for operational time-series logs (via Node.js middleware)

**Layer 2 — Event & Data Bus**
- Platform Events fire on integration failures, SLA breaches, Apex limit hits
- Streaming API (CometD) pushes live updates to LWC components
- Pub/Sub API enables external system subscriptions

**Layer 3 — Automation & Orchestration**
- Record-triggered Flows handle incident lifecycle transitions
- Apex classes run heavy logic: impact calculation, retry orchestration
- Self-Healing Engine executes autonomous actions (retry, restart, escalate)

**Layer 4 — AI Decision Engine**
- Agentforce analyzes incoming telemetry against learned patterns
- Root cause classifier runs on error message + response time + history
- Business Impact Engine computes revenue loss and user exposure
- Confidence scoring on every AI recommendation (0–100%)

**Layer 5 — Presentation**
- Experience Cloud with custom LWC components
- Dark-mode, premium SaaS-style UI (not default Salesforce look)
- Real-time UI updates via Streaming API subscriptions in LWC

---

## 3. Core Modules

### 3.1 Home — Command Center
**Purpose:** System-wide health at a glance.

**Components:**
- KPI cards: Critical Incidents, Warnings, Integrations Active, Revenue Risk, Users Affected, Auto-Healed
- Live incident table with severity tags (Critical/High/Medium/Low)
- AI Insights panel — top 3 root causes with confidence rings
- System health sidebar (Apex Jobs, Platform Events, Flows, Agentforce, API Gateway)

**Data Sources:** `Incident__c`, `Integration_Log__c`, AI inference layer

---

### 3.2 Incidents — Work Queue
**Purpose:** Full incident lifecycle management.

**Components:**
- Filterable, searchable incident table (all fields)
- Severity filter chips (Critical / High / Medium / Low / Open / Resolved)
- Slide-in detail drawer with full Agentforce analysis per incident
- One-click Auto-Heal button — triggers self-healing Flow

**Apex:** `IncidentController.cls` — SOQL queries, status updates, SLA checks
**Flow:** `Incident_Lifecycle_Flow` — New → Investigating → Healing → Resolved transitions

---

### 3.3 Integrations — API Health Monitor
**Purpose:** Real-time health of all connected APIs and services.

**Components:**
- Integration health cards (status, response time, uptime %, error count)
- Integration log table with filter by status (Failed / Warning / Success)
- Per-log AI analysis trigger

**Platform Event:** `Integration_Health_Event__e` fires on threshold breach
**Apex:** `IntegrationMonitorController.cls` — response time tracking, error aggregation

---

### 3.4 Impact Panel — Business Intelligence
**Purpose:** Translate technical failures into business consequences.

**Components:**
- Hero stats: Total Revenue at Risk, Users Affected, Active Impact Events
- Per-incident impact cards: users × ARPU = revenue loss
- Risk level classification: Critical / High / Medium / Low
- AI-generated one-sentence business impact summary

**Formula:** `Revenue Loss = Users Affected × Average Revenue Per User`
**Risk Bands:** Critical (>$50K), High ($10K–$50K), Medium ($1K–$10K), Low (<$1K)

---

### 3.5 AI Copilot — Conversational Operations
**Purpose:** Natural language interface to the entire platform.

**Capabilities:**
- Root cause explanation in plain English
- Revenue impact queries
- Auto-heal command execution via conversation
- SLA breach forecasting
- Incident summary report generation

**Powered by:** Salesforce Agentforce with custom Agent Actions mapped to Apex methods
**Session context:** Maintains full incident + integration state per session

---

## 4. End-to-End Flow

```
[1] SIGNAL DETECTED
    Integration response time > threshold
    OR Apex CPU limit > 80%
    OR Flow error rate spike

[2] PLATFORM EVENT FIRES
    Integration_Health_Event__e published
    Payload: API name, error message, response time, environment

[3] FLOW + APEX TRIGGERED
    Record-triggered Flow creates Incident__c
    Apex sets severity based on SLA_Policy__c thresholds
    IncidentController notifies subscribed LWC components via Streaming API

[4] AGENTFORCE AI ANALYSIS
    Input: status, error_message, response_time, incident history
    Output: root_cause, recommended_action, impact_level, confidence

[5] SELF-HEALING EXECUTION
    If confidence > 85%: auto-execute recommended action
      → Retry: callout retry with exponential backoff
      → Restart Service: Named Credential re-auth + health ping
      → Escalate: Case creation + Slack/email notification

[6] BUSINESS IMPACT CALCULATION
    users_affected × arpu = revenue_at_risk
    Risk level assigned and stored on Incident__c

[7] REAL-TIME UI UPDATE
    Streaming API pushes new incident state to Experience Cloud
    LWC components re-render without page refresh
    AI Insights panel updates with new root cause cards
```

---

## 5. Salesforce Object Model

### `Incident__c`
| Field | Type | Purpose |
|---|---|---|
| Severity__c | Picklist | Critical / High / Medium / Low |
| Status__c | Picklist | Open / Investigating / Healing / Resolved |
| Description__c | Long Text | Incident details |
| Root_Cause__c | Long Text | Agentforce-generated root cause |
| Recommended_Action__c | Text | AI recommended action |
| AI_Confidence__c | Number | 0–100 confidence score |
| Users_Affected__c | Number | Affected user count |
| Revenue_at_Risk__c | Currency | Calculated impact |
| SLA_Policy__c | Lookup | Linked SLA policy |
| Integration_Log__c | Lookup | Triggering log record |
| Environment__c | Lookup | Affected environment |
| Resolved_Time__c | DateTime | Resolution timestamp |

### `Integration_Log__c`
| Field | Type | Purpose |
|---|---|---|
| API_Name__c | Text | Integration identifier |
| Status__c | Picklist | Success / Warning / Failed |
| Response_Time__c | Number | ms |
| Error_Message__c | Long Text | Raw error payload |
| Retry_Count__c | Number | Auto-heal retry attempts |

### `SLA_Policy__c`
| Field | Type | Purpose |
|---|---|---|
| Severity__c | Picklist | Applies to this severity |
| Response_Time_Min__c | Number | Minutes to first response |
| Resolution_Time_Min__c | Number | Minutes to resolution |

---

## 6. AI Agent System Prompt

```
You are the SentinelFlow AI Operations Agent powered by Salesforce Agentforce.

INPUT:
- Integration status: {status}
- Error details: {error_message}
- Response time: {response_time}ms
- Past incidents (last 30 days): {history}

TASKS:
1. Identify the most probable root cause
2. Recommend exactly one action: Retry | Restart Service | Escalate
3. Estimate impact severity: Low | Medium | High | Critical
4. Provide confidence score: 0–100

DECISION RULES:
- Retry if: transient network error, timeout < 3 occurrences in 1h
- Restart Service if: connection pool exhausted, auth token expired, memory leak pattern
- Escalate if: data corruption, security event, unknown error pattern, confidence < 60%

OUTPUT FORMAT (strict JSON):
{
  "root_cause": "string",
  "recommended_action": "Retry | Restart Service | Escalate",
  "impact_level": "Low | Medium | High | Critical",
  "confidence": 0-100,
  "explanation": "1-2 sentence plain English summary"
}
```

---

## 7. Business Impact Engine

```
INPUTS:
- incident_type: string
- users_affected: integer
- avg_revenue_per_user: decimal

CALCULATION:
  revenue_loss = users_affected × avg_revenue_per_user

RISK CLASSIFICATION:
  Critical  → revenue_loss > $50,000
  High      → $10,000 < revenue_loss ≤ $50,000
  Medium    → $1,000 < revenue_loss ≤ $10,000
  Low       → revenue_loss ≤ $1,000

OUTPUT:
  "{users_affected} users impacted across {incident_type},
   estimated ${revenue_loss} revenue at risk — {risk_level} priority."
```

---

## 8. Scalability Design

| Concern | Solution |
|---|---|
| High event volume | Platform Events with replay buffer (72h retention) |
| Large incident datasets | SOQL with selective filters + custom indexes on Severity__c, Status__c |
| AI inference latency | Async Agentforce invocation via Apex `@future` or Queueable |
| Real-time UI at scale | Streaming API with LWC `empApi` — push not poll |
| External API load | Redis-backed queue in Node.js middleware with rate limiting |
| Multi-org support | Environment__c object isolates per-org telemetry |

---

## 9. Security Design

| Layer | Control |
|---|---|
| Authentication | Salesforce SSO + MFA enforced |
| Authorization | Permission Sets: `SentinelFlow_Runtime_Admin`, `SentinelFlow_Portal_Support`, `SentinelFlow_Portal_Viewer` |
| Data visibility | Sharing Rules on `Incident__c` by Environment__c |
| API security | Named Credentials for all external callouts (no hardcoded secrets) |
| Audit | `Audit_Trail__c` records every action with user, timestamp, old/new value |
| Experience Cloud | Guest profile locked down; portal users assigned minimum required permissions |
| AI safety | Agentforce actions scoped to read + approved write operations only |

---

## 10. LWC Component Inventory

| Component | Module | Purpose |
|---|---|---|
| `sentinelKpiCard` | Home | KPI metric display |
| `sentinelIncidentTable` | Home / Incidents | Incident data table |
| `sentinelAiInsightsPanel` | Home | AI root cause cards |
| `sentinelDetailDrawer` | Incidents | Slide-in incident detail |
| `sentinelIntegrationCard` | Integrations | Per-API health card |
| `sentinelImpactPanel` | Impact | Revenue risk visualization |
| `sentinelCopilot` | AI Copilot | Chat interface to Agentforce |
| `sentinelStatusBar` | Global | Top command bar with system health |
| `sentinelHealthSidebar` | Global | Platform health mini-indicators |

---

## 11. Apex Class Inventory

| Class | Purpose |
|---|---|
| `IncidentController` | SOQL, status transitions, SLA checks |
| `IntegrationMonitorController` | Log retrieval, threshold evaluation |
| `AIAnalysisService` | Agentforce invocation, response parsing |
| `SelfHealingEngine` | Retry logic, service restart, escalation routing |
| `BusinessImpactCalculator` | Revenue loss computation, risk classification |
| `PlatformEventPublisher` | Fires `Integration_Health_Event__e` |
| `AuditTrailService` | Writes to `Audit_Trail__c` on every state change |

---

## 12. Flow Inventory

| Flow | Trigger | Purpose |
|---|---|---|
| `Incident_Lifecycle_Flow` | Record (Incident__c) | Status transitions + SLA timer |
| `Integration_Alert_Flow` | Platform Event | Creates Incident from event payload |
| `Self_Heal_Orchestration_Flow` | Apex-invoked | Retry / restart / escalate decisions |
| `SLA_Breach_Notification_Flow` | Scheduled | Fires alerts before SLA breach |
| `Impact_Calculation_Flow` | Record (Incident__c) | Computes revenue risk on save |

---

*SentinelFlow · Built by Tomcodex · Salesforce Agentforce + Experience Cloud*
