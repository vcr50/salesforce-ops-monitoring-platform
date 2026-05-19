# SentinelFlow — Professional Implementation Plan

> Synthesized from **CTO Implementation Blueprint** + **AppExchange Safe Blueprint**
> Prepared: 2026-05-15 | Version: 1.0

---

## 1. Executive Summary

SentinelFlow is transitioning from a **Salesforce-native monitoring tool** into an **Autonomous Business Protection Platform**. This plan reconciles both blueprints into a single executable roadmap with four delivery phases, grounded in the current codebase reality.

### Strategic Principles (from both blueprints)

| Principle | Source |
|---|---|
| Salesforce package must remain **independently installable** and AppExchange-compliant | AppExchange Blueprint |
| External SaaS is an **optional enhancement**, never a hard dependency | AppExchange Blueprint |
| Product must feel **intelligent, autonomous, calm, and business-aware** | CTO Blueprint |
| Every screen must answer: *"What matters right now?"* | Both |
| Connect **workflow failure → business impact** (core differentiator) | Both |
| Complex backend, extremely simple frontend | CTO Blueprint |

---

## 2. Current State Assessment

### ✅ What Already Exists

| Layer | Assets | Status |
|---|---|---|
| **Data Model** | `Incident__c`, `Integration_Endpoint__c`, `Integration_Log__c`, `Retry_Log__c`, `SLA_Policy__c`, `Subscription__c`, `Tenant__c`, `Audit_Trail__c`, `System_Log__c` | ✅ Deployed |
| **Metadata** | `AI_Rule__mdt`, `FeatureFlag__mdt`, `System_Setting__mdt` | ✅ Deployed |
| **Platform Events** | `Integration_Health_Event__e` | ✅ Deployed |
| **Core Apex** | `SelfHealingEngine`, `AIAnalysisService`, `BusinessImpactCalculator`, `ScheduledMonitoringJob`, `AutoHealQueueable`, `RetryLogService`, `NotificationService`, `RateLimiter` | ✅ Deployed |
| **Licensing** | `LicenseService`, `LicenseValidator`, `LicenseCacheService`, `SubscriptionService` | ✅ Deployed |
| **Portal LWC** | CommandCenter, IncidentTable/Detail, IntegrationTable/Detail, Copilot, Charts, Timeline, Settings, ImpactPanel, Summary, Login | ✅ Deployed |
| **Experience Cloud** | SentinelFlow1 site with theme header/sidebar | ✅ Deployed |
| **Marketing Site** | Next.js website with homepage, about, blog, products, careers, contact, dashboard | ✅ Built |

### ❌ Gaps vs. Blueprint Vision

| Blueprint Requirement | Gap Level | Notes |
|---|---|---|
| **Revenue_Risk__c** object | 🔴 Missing | Blueprint specifies this as core data object |
| **Flow_Health__c** object | 🔴 Missing | Required for Flow Shield module |
| **Auto_Heal_Run__c** object | 🔴 Missing | Required for auto-heal audit trail |
| **AI_Decision__c** object | 🔴 Missing | Required for AI Guardian decision logging |
| **Revenue Pulse Engine** | 🔴 Missing | Core differentiator — not yet built |
| **AI Guardian Home** screen | 🟡 Partial | Copilot exists, but not the "Guardian Home" experience |
| **Flow Shield** module | 🟡 Partial | Monitoring exists but no dedicated Flow failure detection |
| **Apex Job Shield** module | 🔴 Missing | No Batch/Queueable/Scheduled job monitoring |
| **Business-impact language in UI** | 🟡 Partial | ImpactPanel exists but needs revenue context |
| **One-click remediation UX** | 🟡 Partial | Auto-heal engine exists, UX needs simplification |
| **External SaaS layer** | 🔴 Not started | Phase 2 — intentionally deferred |

---

## 3. Architecture Decision Record

### ADR-1: Dual-Product Architecture

```
┌─────────────────────────────────────────────┐
│  Product 1: SentinelFlow for Salesforce      │
│  (AppExchange — Fully Independent)           │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │Flow      │  │Apex Job  │  │Integration│  │
│  │Shield    │  │Shield    │  │Health     │  │
│  └──────────┘  └──────────┘  └───────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │Revenue   │  │AI        │  │Auto-Heal  │  │
│  │Risk Eng. │  │Guardian  │  │Playbooks  │  │
│  └──────────┘  └──────────┘  └───────────┘  │
│                                              │
│  Tech: LWC, Apex, Platform Events, CMDT     │
└──────────────────┬──────────────────────────┘
                   │ (Optional API bridge)
┌──────────────────▼──────────────────────────┐
│  Product 2: SentinelFlow Cloud (Future)      │
│  (External SaaS — Optional Enhancement)      │
│                                              │
│  Node.js · NestJS · PostgreSQL · Redis       │
│  Kafka · Socket.IO · React/Next.js           │
│                                              │
│  Advanced AI · Cross-platform connectors     │
│  Predictive analytics · Workflow graphs      │
└─────────────────────────────────────────────┘
```

### ADR-2: AppExchange Firewall Rule

> **RULE**: No Salesforce component may have a hard dependency on external services. All external integrations must be gated behind `FeatureFlag__mdt` and degrade gracefully.

### ADR-3: AI Strategy Staging

| Stage | Scope | Dependency |
|---|---|---|
| Stage 1 — Assistive | Explain, summarize, recommend | Salesforce-native only |
| Stage 2 — Semi-Autonomous | Safe retries, escalation workflows | Salesforce-native + optional external |
| Stage 3 — Controlled Autonomy | Autonomous recovery, predictive | Requires external AI layer |

---

## 4. Phased Execution Plan

### Phase 1 — Foundation Hardening (Weeks 1–3)

> **Goal**: Close all critical data-model gaps, establish the missing objects and core services that both blueprints require.

#### Sprint 1.1 — Missing Custom Objects (Week 1)

| # | Task | Type | Priority |
|---|---|---|---|
| 1.1.1 | Create `Revenue_Risk__c` object with fields: `Name`, `Risk_Amount__c` (Currency), `Risk_Level__c` (Picklist: Low/Medium/High/Critical), `Related_Incident__c` (Lookup→Incident), `Affected_Pipeline__c` (Currency), `Status__c`, `Resolution_Date__c` | Object | 🔴 P0 |
| 1.1.2 | Create `Flow_Health__c` object with fields: `Flow_API_Name__c`, `Flow_Label__c`, `Last_Run_Status__c`, `Failure_Count__c`, `Last_Failure_Date__c`, `Error_Message__c`, `Affected_Records__c` | Object | 🔴 P0 |
| 1.1.3 | Create `Auto_Heal_Run__c` object with fields: `Playbook_Name__c`, `Trigger_Incident__c` (Lookup→Incident), `Status__c`, `Execution_Log__c` (Long Text), `Success__c` (Checkbox), `Duration_ms__c` | Object | 🔴 P0 |
| 1.1.4 | Create `AI_Decision__c` object with fields: `Decision_Type__c`, `Confidence_Score__c`, `Recommendation__c`, `Was_Accepted__c`, `Related_Incident__c` (Lookup), `Reasoning__c` (Long Text) | Object | 🟡 P1 |
| 1.1.5 | Create layouts, list views, and tab visibility for all new objects | Config | 🟡 P1 |
| 1.1.6 | Add new objects to `SentinelFlow_Admin` and `SentinelFlow_User` permission sets | Security | 🔴 P0 |

#### Sprint 1.2 — Flow Shield Service (Week 2)

| # | Task | Type | Priority |
|---|---|---|---|
| 1.2.1 | Build `FlowHealthMonitor.cls` — queries `FlowInterview` and `FlowInterviewLog` to detect failed Flow runs | Apex | 🔴 P0 |
| 1.2.2 | Build `FlowHealthSchedulable.cls` — scheduled job that runs FlowHealthMonitor every 15 min | Apex | 🔴 P0 |
| 1.2.3 | Create `Flow_Health_Event__e` platform event for real-time Flow failure alerts | Platform Event | 🟡 P1 |
| 1.2.4 | Write `FlowHealthMonitorTest.cls` with ≥90% coverage | Test | 🔴 P0 |

#### Sprint 1.3 — Apex Job Shield Service (Week 3)

| # | Task | Type | Priority |
|---|---|---|---|
| 1.3.1 | Build `ApexJobMonitor.cls` — queries `AsyncApexJob` for failed Batch, Queueable, Scheduled jobs | Apex | 🔴 P0 |
| 1.3.2 | Auto-create `Incident__c` records for critical job failures | Apex | 🔴 P0 |
| 1.3.3 | Add Apex Job Shield results to `ScheduledMonitoringJob.cls` execution chain | Apex | 🟡 P1 |
| 1.3.4 | Write `ApexJobMonitorTest.cls` with ≥90% coverage | Test | 🔴 P0 |

---

### Phase 2 — Intelligence Layer (Weeks 4–7)

> **Goal**: Build the Revenue Pulse Engine and evolve the AI Guardian experience — the two core differentiators.

#### Sprint 2.1 — Revenue Pulse Engine (Weeks 4–5)

| # | Task | Type | Priority |
|---|---|---|---|
| 2.1.1 | Enhance `BusinessImpactCalculator.cls` to write `Revenue_Risk__c` records linking failures to pipeline amounts | Apex | 🔴 P0 |
| 2.1.2 | Build `RevenuePulseService.cls` — aggregates risk across all active incidents and produces org-wide revenue exposure score | Apex | 🔴 P0 |
| 2.1.3 | Add `@AuraEnabled` methods to `SentinelFlowPortalController` for revenue pulse data | Apex | 🔴 P0 |
| 2.1.4 | Build `sentinelFlowRevenueRiskPanel` LWC — displays "₹X pipeline at risk" with severity breakdown | LWC | 🔴 P0 |
| 2.1.5 | Add revenue context to `sentinelFlowPortalImpactPanel` — transform "17 failed flows" → "Lead routing failures affecting ₹18L pipeline" | LWC | 🔴 P0 |
| 2.1.6 | Write `RevenuePulseServiceTest.cls` with ≥90% coverage | Test | 🔴 P0 |

#### Sprint 2.2 — AI Guardian Home (Weeks 6–7)

| # | Task | Type | Priority |
|---|---|---|---|
| 2.2.1 | Build `sentinelFlowGuardianHome` LWC — the single-screen "What matters right now?" experience | LWC | 🔴 P0 |
| 2.2.2 | AI Guardian Home must show: active threat count, revenue at risk, top 3 recommended actions, system health pulse | LWC | 🔴 P0 |
| 2.2.3 | Enhance `AIAnalysisService.cls` to produce business-language summaries (Stage 1 — Assistive AI) | Apex | 🟡 P1 |
| 2.2.4 | Enhance `SentinelFlowCopilotController.cls` with Guardian-mode responses using `AI_Decision__c` logging | Apex | 🟡 P1 |
| 2.2.5 | Add one-click remediation buttons that trigger `SelfHealingEngine` playbooks from Guardian Home | LWC + Apex | 🟡 P1 |
| 2.2.6 | Write `Auto_Heal_Run__c` records for every auto-heal execution for full audit trail | Apex | 🔴 P0 |

---

### Phase 3 — UX Transformation & AppExchange Readiness (Weeks 8–10)

> **Goal**: Transform the experience from "dashboards + tables" to "AI operational guidance" and pass AppExchange security review.

#### Sprint 3.1 — UX Overhaul (Week 8–9)

| # | Task | Type | Priority |
|---|---|---|---|
| 3.1.1 | Redesign `sentinelFlowPortalCommandCenter` to lead with Guardian Home as default view | LWC | 🔴 P0 |
| 3.1.2 | Replace raw metric displays with business-language statements throughout all portal components | LWC | 🟡 P1 |
| 3.1.3 | Add micro-animations and state transitions for operational calm (loading states, status changes) | CSS/LWC | 🟡 P1 |
| 3.1.4 | Ensure full mobile-responsive parity across all portal LWCs | CSS | 🔴 P0 |
| 3.1.5 | Simplify Settings page — reduce admin overload per UX philosophy | LWC | 🟢 P2 |

#### Sprint 3.2 — AppExchange Compliance (Week 10)

| # | Task | Type | Priority |
|---|---|---|---|
| 3.2.1 | Run Salesforce CLI `sf scanner` — fix all Critical/High findings | Security | 🔴 P0 |
| 3.2.2 | Validate all Apex classes achieve ≥75% test coverage (target ≥90%) | Test | 🔴 P0 |
| 3.2.3 | Verify all CRUD/FLS checks in Apex controllers (`WITH SECURITY_ENFORCED` or `SecurityUtils`) | Security | 🔴 P0 |
| 3.2.4 | Ensure no hardcoded IDs, org-specific references, or external callouts without Named Credentials | Security | 🔴 P0 |
| 3.2.5 | Validate `SentinelFlowPostInstallHandler.cls` creates correct default data | Package | 🟡 P1 |
| 3.2.6 | Prepare AppExchange listing content: screenshots, description, install guide | Docs | 🟡 P1 |
| 3.2.7 | Submit security review to Salesforce | Milestone | 🔴 P0 |

---

### Phase 4 — External Intelligence Layer (Weeks 11–16)

> **Goal**: Build the optional SaaS platform that enhances (never replaces) the Salesforce product.

> [!IMPORTANT]
> This phase is **optional** per the AppExchange Safe Blueprint. The Salesforce product MUST be fully functional without any Phase 4 components.

#### Sprint 4.1 — API Bridge (Weeks 11–12)

| # | Task | Type | Priority |
|---|---|---|---|
| 4.1.1 | Design REST API contract between SF package and external SaaS | Architecture | 🟡 P1 |
| 4.1.2 | Build `ExternalIntelligenceConnector.cls` gated behind `FeatureFlag__mdt` | Apex | 🟡 P1 |
| 4.1.3 | Ensure graceful degradation — if external API is unreachable, SF package continues normally | Apex | 🔴 P0 |
| 4.1.4 | Set up Named Credential for external SaaS endpoint | Config | 🟡 P1 |

#### Sprint 4.2 — SaaS Backend Foundation (Weeks 13–14)

| # | Task | Type | Priority |
|---|---|---|---|
| 4.2.1 | Initialize NestJS backend project with PostgreSQL and Redis | Backend | 🟡 P1 |
| 4.2.2 | Build Salesforce connector — ingest incidents, health data via REST | Backend | 🟡 P1 |
| 4.2.3 | Build advanced AI reasoning service (predictive failure analysis) | Backend | 🟡 P1 |
| 4.2.4 | Set up Kafka for event streaming | Backend | 🟢 P2 |

#### Sprint 4.3 — SaaS Frontend & Connectors (Weeks 15–16)

| # | Task | Type | Priority |
|---|---|---|---|
| 4.3.1 | Build SentinelFlow Cloud dashboard in Next.js (cross-platform view) | Frontend | 🟡 P1 |
| 4.3.2 | Build initial connectors: HubSpot, Stripe | Backend | 🟢 P2 |
| 4.3.3 | Implement Socket.IO for real-time cross-platform alerts | Backend | 🟢 P2 |

---

## 5. Product Line Summary

| Product | Target | Revenue Model | Timeline |
|---|---|---|---|
| **SentinelFlow for Salesforce** | AppExchange listing, Salesforce admins & RevOps teams | Subscription (Starter/Professional/Enterprise tiers) | Phases 1–3 |
| **SentinelFlow Cloud** | Mid-market companies using multiple platforms | SaaS subscription | Phase 4 |
| **SentinelFlow Enterprise Intelligence** | Large enterprises needing cross-platform orchestration | Enterprise licensing | Future |

---

## 6. Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| AppExchange security review rejection | 🔴 High | Run `sf scanner` early; enforce CRUD/FLS checks from Sprint 1 |
| Governor limit violations under load | 🔴 High | Bulkify all queries; use `Queueable` chains; stress test in Phase 3 |
| Revenue Pulse accuracy — incorrect pipeline mapping | 🟡 Medium | Allow manual override; start with conservative estimates |
| AI hallucination in Guardian summaries | 🟡 Medium | Keep AI Stage 1 (assistive only); log all decisions to `AI_Decision__c` |
| External SaaS dependency creep into SF package | 🔴 High | Enforce ADR-2 firewall rule; code review gate for all callouts |
| Scope creep on connectors | 🟡 Medium | Phase 4 connectors are P2; ship SF product first |

---

## 7. Success Metrics

| Metric | Target | Measurement |
|---|---|---|
| AppExchange security review | ✅ Passed | Salesforce review outcome |
| Apex test coverage | ≥ 90% | `sf apex run test` |
| Incident detection latency | < 5 minutes | Time from failure to `Incident__c` creation |
| Auto-heal success rate | ≥ 70% | `Auto_Heal_Run__c.Success__c` ratio |
| Revenue Risk accuracy | Manual validation pass | Spot-check 20 incidents against actual pipeline |
| Guardian Home load time | < 2 seconds | LWC performance profiler |
| Zero external hard dependencies | 0 callouts without feature flag gate | Code scan |

---

## 8. Immediate Next Steps

1. **Start Sprint 1.1** — Create the four missing custom objects (`Revenue_Risk__c`, `Flow_Health__c`, `Auto_Heal_Run__c`, `AI_Decision__c`)
2. **Prioritize Flow Shield** (Sprint 1.2) — highest customer-pain module
3. **Revenue Pulse Engine** is the #1 differentiator — begin design during Week 2

> [!TIP]
> The fastest path to AppExchange listing is completing **Phases 1–3** (10 weeks). Phase 4 can run independently afterward without blocking the Salesforce product launch.

---

*North Star: "Build the platform businesses trust when broken workflows threaten revenue."*
