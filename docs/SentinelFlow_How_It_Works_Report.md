# SentinelFlow — How The Product Works

> Complete End-to-End Product Report

---

## 1. What SentinelFlow Does (One Sentence)

SentinelFlow **automatically detects when business workflows break**, figures out **why** they broke, **fixes them autonomously** when possible, and tells you **how much revenue is at risk** — all inside Salesforce.

---

## 2. The Complete Lifecycle

```text
INSTALL ──► DETECT ──► ANALYSE ──► HEAL ──► PROTECT
  │            │          │          │          │
  │            │          │          │          │
  ▼            ▼          ▼          ▼          ▼
Package    Scheduled    AI Rule    Auto-Retry  Revenue
installs   monitoring   matching   or Escalate Risk
+ Trial    finds        gives root via Self-   Dashboard
starts     failures     cause      Healing    shows ₹
                                   Engine     impact
```

---

## 3. Step 1 — Installation & Subscription

### What Happens When Customer Installs

1. Customer installs the managed package from **AppExchange**
2. `SentinelFlowPostInstallHandler` runs automatically and creates default data
3. `SubscriptionService` creates a **14-day Trial** on Starter plan

### Subscription Tiers

| Feature | Starter (Free Trial) | Professional | Enterprise |
|---|---|---|---|
| Price | 14-day free trial | Paid | Paid |
| Incident monitoring | ✅ (100/month limit) | ✅ Unlimited | ✅ Unlimited |
| Integration health logs | ✅ | ✅ | ✅ |
| AI analysis | ❌ | ✅ | ✅ |
| Auto-heal (self-healing) | ❌ | ✅ | ✅ |
| Business impact calculator | ❌ | ✅ | ✅ |
| Multi-tenant isolation | ❌ | ❌ | ✅ |

**Gating logic** — when a Starter user clicks "Heal" or "Analyse":
```
User clicks "Heal Incident" in portal
  → PortalController.healIncident()
    → SubscriptionService.requireProfessional('Autonomous self-healing')
      → Plan = Starter? → BLOCK → "Requires Professional subscription"
      → Plan = Professional/Enterprise? → ALLOW → SelfHealingEngine runs
```

---

## 4. Step 2 — How Failures Are Detected

SentinelFlow detects failures through **3 channels**:

### Channel A — Scheduled Monitoring (Automated)

`ScheduledMonitoringJob` runs **every 15 minutes** via Salesforce Scheduled Apex:

```text
Every 15 min → ScheduledMonitoringJob.execute()
  │
  ├── sweepStaleFailed()
  │   "Find Integration_Log__c records with Status = 'Failed'
  │    that are older than 30 minutes and have no open Incident"
  │   → Auto-creates Incident__c (Severity: High)
  │   → Queues AIAnalysisQueueable for AI root cause
  │
  └── sweepSilentStalled()
      "Find Integration_Log__c records with no activity for 60+ minutes"
      → Auto-creates Incident__c (Severity: Medium)
      → Queues AIAnalysisQueueable for AI root cause
```

**Key**: Failures that happen silently (no error, just stopped working) are caught by the **stalled detection** — this is the "silent failure" problem SentinelFlow solves.

### Channel B — Real-Time Platform Events

When an integration fails, `PlatformEventPublisher` fires `Integration_Health_Event__e`:

```text
Integration API call fails
  → PlatformEventPublisher.publish(Integration_Health_Event__e)
    → Trigger/subscriber catches event in real-time
      → Creates Integration_Log__c + Incident__c immediately
```

### Channel C — Manual Incident Creation (Portal UI)

Admins can create incidents from the portal:

```text
User fills form in Portal → createSimulatedIncident()
  → Creates Integration_Log__c (Status: Failed)
  → Creates Incident__c (Status: New)
  → Queues AIAnalysisQueueable (async AI analysis)
  → AuditTrailService logs the action
```

---

## 5. Step 3 — AI Analysis (Root Cause Detection)

Once an Incident exists, `AIAnalysisService` determines **why** it happened.

### How AI Rules Work

AI analysis is driven by **Custom Metadata** (`AI_Rule__mdt`) — configurable without code:

```text
AI_Rule__mdt records (examples):
┌──────────────┬────────────────────────┬──────────────┬────────┐
│ Keyword      │ Root Cause             │ Action       │ Conf.  │
├──────────────┼────────────────────────┼──────────────┼────────┤
│ timeout      │ API timeout            │ Retry        │ 90%    │
│ 401          │ Auth token expired     │ Token Refresh│ 95%    │
│ 503          │ Service unavailable    │ Retry        │ 85%    │
│ rate limit   │ API rate limit hit     │ Retry        │ 88%    │
│ connection   │ Connection refused     │ Restart      │ 80%    │
└──────────────┴────────────────────────┴──────────────┴────────┘
```

### Analysis Flow

```text
Incident created → AIAnalysisQueueable (async)
  │
  ├── Read error message from Integration_Log__c
  │
  ├── Compare against AI_Rule__mdt keywords
  │     Error contains "timeout"? → Match! → Root Cause: "API timeout"
  │                                         → Action: "Retry"
  │                                         → Confidence: 90%
  │
  ├── No rule match? → Check response time
  │     Response > 5000ms? → Root Cause: "Response time degradation"
  │                        → Action: "Restart Service"
  │                        → Confidence: 75%
  │
  ├── Still no match? → Fallback
  │     → Root Cause: "Unknown error — manual investigation"
  │     → Action: "Escalate"
  │     → Confidence: 50%
  │
  └── Update Incident__c with:
        Root_Cause__c, Recommended_Action__c,
        AI_Impact_Level__c, AI_Confidence__c
```

---

## 6. Step 4 — Self-Healing Engine

The `SelfHealingEngine` is the autonomous recovery system. It executes 4 types of actions:

### Auto-Heal Pipeline

```text
AI says "Retry" with 90% confidence
  │
  ├── Confidence ≥ 85%? → AUTO-EXECUTE (no human needed)
  │
  └── Confidence < 85%? → Mark "Not Attempted" (human decides)
```

### Heal Actions

| Action | What It Does | When Used |
|---|---|---|
| **Retry** | Re-attempts the failed API call, increments retry counter | Timeout, rate limit, transient errors |
| **Restart Service** | Triggers service restart via Named Credential callout | Service degradation, memory issues |
| **Token Refresh** | Refreshes OAuth token for auth failures | 401 errors, expired credentials |
| **Escalate** | Creates a Salesforce Case, notifies ops team | Unknown errors, max retries exceeded |

### Circuit Breaker Protection

The circuit breaker prevents SentinelFlow from hammering a broken endpoint:

```text
Endpoint failure count tracking:
  Failure 1 → count = 1 (Circuit: Closed → keep calling)
  Failure 2 → count = 2 (Circuit: Closed → keep calling)
  Failure 3 → count = 3 (Circuit: Closed → keep calling)
  Failure 4 → count = 4 (Circuit: Closed → keep calling)
  Failure 5 → count = 5 (Circuit: OPEN → STOP all calls)
  
  Circuit OPEN = "This endpoint is broken. Don't call it."
  → All future heal attempts → SKIP → Escalate immediately
  → Admin can manually reset via portal "Reset Circuit Breaker"
```

### Retry Limit Enforcement

```text
Incident retry flow:
  Retry 1 → Success? → Status: Resolved ✅
  Retry 1 → Fail?    → Retry 2
  Retry 2 → Fail?    → Retry 3
  Retry 3 → Fail?    → Max retries (3) exceeded
                       → Status: Escalated
                       → Case created for ops team
                       
  Max retries configurable via:
    - Incident__c.Max_Retry__c (per incident)
    - SentinelFlow_Settings__c.Max_Retry__c (org-wide override)
```

### Incident Lifecycle (Status Flow)

```text
New → Healing → Resolved ✅  (auto-heal succeeded)
New → Healing → Escalated ⚠️  (auto-heal failed → Case created)
New → Escalated ⚠️  (circuit breaker open, or low AI confidence)
New → Closed 🔒  (manually resolved by admin)
```

---

## 7. Step 5 — Business Impact & Revenue Risk

`BusinessImpactCalculator` translates technical failures into **business language**.

### Revenue Calculation

```text
Revenue at Risk = Users Affected × Average Revenue Per User (ARPU)

ARPU defaults by severity:
  Critical = $40/user
  High     = $30/user
  Medium   = $20/user
  Low      = $10/user

User estimate (when not specified):
  Critical = 1,000 users
  High     = 500 users
  Medium   = 100 users
  Low      = 25 users
```

### Risk Classification

| Revenue at Risk | Risk Level | Example |
|---|---|---|
| > $50,000 | 🔴 Critical | "Lead routing failure affecting 1,000 enterprise users" |
| $10,000 – $50,000 | 🟠 High | "Payment webhook down — 500 transactions pending" |
| $1,000 – $10,000 | 🟡 Medium | "Email automation paused — 100 contacts affected" |
| ≤ $1,000 | 🟢 Low | "Report generation delayed — 25 users waiting" |

### What Users See (Instead of Raw Metrics)

| Raw Metric | SentinelFlow Shows |
|---|---|
| "17 failed flows" | "Lead routing failures affecting enterprise opportunities" |
| "3 API errors" | "Payment webhook down — ₹3.5L revenue at risk" |
| "Response time: 8200ms" | "Severe degradation — quote approval delayed for 500 users" |

---

## 8. Step 6 — Portal Experience (What Users See)

### Portal Pages

| Page | What It Shows |
|---|---|
| **Command Center** | Overview — critical count, open incidents, failed integrations, revenue at risk, auto-healed today |
| **Incidents** | Table of all open incidents with severity, status, AI root cause, recommended action |
| **Incident Detail** | Full detail + timeline + AI analysis + "Heal" button + auto-heal status |
| **Integrations** | All integration logs — success/fail status, response times |
| **Integration Detail** | Endpoint detail + error messages + linked incidents + "Reset Circuit Breaker" |
| **AI Copilot** | Chat interface — ask questions about incidents, get AI guidance |
| **Impact Panel** | Revenue at risk, users affected, risk level breakdown |
| **Charts** | Trend visualization — health over time |
| **Timeline** | Chronological event history per incident |
| **Settings** | Manage integration endpoints (CRUD), configure auth, retry policies |
| **Subscription** | Current plan, usage, upgrade path |

### User Journey Example

```text
Admin opens SentinelFlow Portal
  │
  ├── Command Center shows:
  │   "2 Critical Incidents | ₹18L Revenue at Risk | 5 Auto-Healed Today"
  │
  ├── Clicks incident "INC-00042"
  │   → Incident Detail shows:
  │     Severity: Critical
  │     Root Cause: "API timeout on Stripe payment webhook"
  │     Recommended Action: "Retry"
  │     AI Confidence: 92%
  │     Revenue at Risk: ₹3.5L
  │     Auto-Heal Status: In Progress
  │
  ├── Clicks "Heal Incident" button
  │   → SelfHealingEngine.healIncident() runs
  │   → Retry executed
  │   → Status changes: Healing → Resolved ✅
  │   → Audit trail logged
  │
  └── Command Center updates:
      "1 Critical Incident | ₹14.5L Revenue at Risk | 6 Auto-Healed Today"
```

---

## 9. Multi-Tenant Architecture

SentinelFlow supports **multi-tenant isolation** — each customer's data is separated:

```text
Customer A (Tenant__c = "001xx...")
  → Only sees their Incidents, Logs, Endpoints
  
Customer B (Tenant__c = "001yy...")
  → Only sees their Incidents, Logs, Endpoints

How it works:
  Every query runs through TenantContext.getCurrentTenantId()
  → Adds WHERE Tenant__c = :tenantId to all SOQL
  → Zero data leakage between tenants
```

---

## 10. Notification System

When incidents are created or escalated, `NotificationService` alerts the right people:

| Channel | How | When |
|---|---|---|
| **Slack** | Webhook via Named Credential (`Slack_Webhook`) | Critical/High incidents |
| **Email** | Salesforce Email Service | Escalations, subscription events |
| **Platform Events** | `Integration_Health_Event__e` | Real-time UI updates |
| **Salesforce Cases** | Auto-created by `SelfHealingEngine.doEscalate()` | Max retries exceeded |

---

## 11. Audit & Compliance

Every action in SentinelFlow is logged to `Audit_Trail__c`:

| Event | Logged Data |
|---|---|
| Incident Created | Source, tenant, timestamp |
| AI Analysis Run | Rule matched, confidence, recommended action |
| Self-Heal Executed | Action taken, result (success/fail), heal status |
| Circuit Breaker Tripped | Endpoint ID, failure count |
| Circuit Breaker Reset | Reset by (username) |
| Endpoint Created/Updated | Name, auth type, who changed |
| Business Impact Calculated | Revenue at risk, risk level, summary |

---

## 12. External App Connectivity (Connector Framework)

### How SentinelFlow Monitors External Apps

```text
Step 1: Admin adds endpoint in Settings page
        Name: "Stripe Payments"
        URL: callout:Stripe/v1/payment_intents
        Auth: API Key
        Retry Policy: Exponential Backoff
        Max Retries: 3

Step 2: ScheduledMonitoringJob polls every 15 min
        → ConnectorBase.executeMonitoredCall()
        → Calls Stripe API via Named Credential
        → Logs result to Integration_Log__c

Step 3: If Stripe returns error (4xx/5xx)
        → Integration_Log__c (Status: Failed)
        → Incident__c auto-created
        → AIAnalysisService identifies root cause
        → SelfHealingEngine retries or escalates
        → BusinessImpactCalculator: "₹3.5L at risk"
        → NotificationService alerts Slack + Email

Step 4: If 5 consecutive failures
        → Circuit breaker OPENS
        → Stops calling Stripe
        → Escalation Case created
        → Admin gets alert: "Stripe endpoint circuit open"
```

### Supported Platforms (50 Connectors, 8 Categories)

| Category | Count | Key Platforms |
|---|---|---|
| CRM | 7 | Salesforce, Zoho, HubSpot, Pipedrive, Dynamics 365 |
| ERP & Finance | 8 | SAP, NetSuite, Oracle, QuickBooks, Tally |
| Payments | 7 | Stripe, Razorpay, PayPal, Square, Zuora |
| E-Commerce | 5 | Shopify, WooCommerce, Magento, BigCommerce |
| Marketing | 7 | Marketo, Mailchimp, SendGrid, Pardot, CleverTap |
| Support | 5 | Zendesk, Freshdesk, ServiceNow, Intercom |
| Communication | 5 | Slack, MS Teams, Twilio, WhatsApp, PagerDuty |
| Cloud/DevOps | 6 | AWS, Azure, GCP, Jira, GitHub, Datadog |

---

## 13. Complete Data Flow Summary

```text
╔═══════════════════════════════════════════════════════════╗
║              SENTINELFLOW — COMPLETE DATA FLOW            ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  External Systems (Stripe, SAP, Zoho, etc.)               ║
║       │                                                   ║
║       ▼                                                   ║
║  Named Credentials (secure auth)                          ║
║       │                                                   ║
║       ▼                                                   ║
║  Integration_Log__c ──────────────────────────────────┐   ║
║       │                                               │   ║
║       │ (if failed)                          (if OK)  │   ║
║       ▼                                               ▼   ║
║  Incident__c (auto-created)              Dashboard ✅  ║
║       │                                               ║
║       ├──► AIAnalysisService                          ║
║       │    └── AI_Rule__mdt matching                  ║
║       │    └── Root cause + Recommended action        ║
║       │                                               ║
║       ├──► BusinessImpactCalculator                   ║
║       │    └── Revenue at Risk = Users × ARPU         ║
║       │    └── Risk Level (Critical/High/Med/Low)     ║
║       │                                               ║
║       ├──► SelfHealingEngine                          ║
║       │    ├── Retry (if confidence ≥ 85%)            ║
║       │    ├── Token Refresh (if 401)                 ║
║       │    ├── Restart (if degradation)               ║
║       │    └── Escalate (if unknown/max retries)      ║
║       │         └── Creates Salesforce Case           ║
║       │                                               ║
║       ├──► NotificationService                        ║
║       │    ├── Slack webhook alert                    ║
║       │    ├── Email notification                     ║
║       │    └── Platform Event (real-time UI)          ║
║       │                                               ║
║       ├──► AuditTrailService                          ║
║       │    └── Every action logged to Audit_Trail__c  ║
║       │                                               ║
║       └──► RetryLogService                            ║
║            └── Retry attempts logged to Retry_Log__c  ║
║                                                       ║
║  All data flows through TenantContext                 ║
║  (multi-tenant isolation)                             ║
║                                                       ║
║  All premium features gated by SubscriptionService    ║
║  (Starter → Professional → Enterprise)                ║
╚═══════════════════════════════════════════════════════╝
```

---

## 14. Why This Matters

| Traditional Monitoring | SentinelFlow |
|---|---|
| "Alert: 5 API errors" | "Stripe payment webhook failing — ₹3.5L revenue at risk" |
| Manual investigation | AI root cause: "Token expired" → Auto-refreshes |
| Dashboard fatigue | Guardian Home: "What matters right now?" |
| Siloed per system | 50 connectors across all business platforms |
| Reactive | Proactive — detects silent failures before users notice |
| Technical language | Business language — revenue, users, pipeline impact |

---

*"The platform businesses trust when broken workflows threaten revenue."*
