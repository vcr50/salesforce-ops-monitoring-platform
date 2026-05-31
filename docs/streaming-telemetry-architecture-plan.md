# Streaming Telemetry Architecture Plan (Milestone 48A)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Design — Pending Review  
**Version**: 1.0  

---

## 1. Purpose

Replace the Command Center's polling-based data refresh with **real-time streaming telemetry** using Salesforce Platform Events and the Lightning Messaging Service (`lightning/empApi`). This upgrade enables operators to see incident state changes, approval transitions, and execution outcomes the moment they happen — without waiting for the next polling cycle.

> [!IMPORTANT]
> **Design principle**: Streaming is added as an **enhancement layer**. The existing 30-second polling mechanism is **not removed**. It continues to serve as the guaranteed fallback for environments where streaming is unavailable, rate-limited, or experiences transient failures.

---

## 2. Current Polling Model

The primary Command Center dashboard (`zentomDashboard` LWC) uses a **timer-driven polling** architecture:

### Data Flow

```
┌──────────────────┐   @wire (initial)    ┌─────────────────────────────┐
│  zentomDashboard │ ───────────────────►  │ ZentomDashboardController   │
│       (LWC)      │   setInterval(30s)   │     .getDashboardData()     │
│                  │ ───refreshApex()────► │                             │
└──────────────────┘                      └──────────┬──────────────────┘
                                                     │
                                          ┌──────────▼──────────────────┐
                                          │  7-9 SOQL queries per call  │
                                          │  • queryIncidents (×3)      │
                                          │  • getPendingApprovalRows   │
                                          │  • getRecentExecutions      │
                                          │  • getRecentReplayEvents    │
                                          │  • getRecentCasesCreated    │
                                          │  • getReplayEventCount      │
                                          │  • getErrorLogCount         │
                                          │  • latestAiSignal (1 SOQL)  │
                                          │  • latestCriticalIncident   │
                                          └─────────────────────────────┘
```

### Key Parameters

| Parameter | Value | Source |
|---|---|---|
| Poll interval | 30,000 ms (30 seconds) | `POLL_INTERVAL_MS` constant in `zentomDashboard.js` |
| Refresh mechanism | `setInterval` → `refreshApex()` | `connectedCallback()` lifecycle hook |
| Wire adapter | `@wire(getDashboardData, { dateRange })` | Cached via `cacheable=true` |
| SOQL queries per refresh | ~9-11 queries | `ZentomDashboardController.getDashboardData()` |
| Row limits | 6–2000 per query | `LIMIT` clauses in each sub-method |
| Objects queried | `Sentinel_Incident__c`, `Sentinel_Audit_Log__c`, `Case` | Via direct SOQL |

### Existing Streaming Infrastructure

The project **already has** partial streaming infrastructure in the Portal tier:

| Component | Platform Event | Usage |
|---|---|---|
| `sentinelFlowPortalSummary` | `Integration_Health_Event__e` | Subscribes via `empApi`; triggers re-fetch on event |
| `sentinelFlowPortalImpactPanel` | `Integration_Health_Event__e` | Subscribes via `empApi`; triggers re-fetch on event |
| `sentinelFlowPortalIncidentTable` | `Integration_Health_Event__e` | Subscribes via `empApi`; triggers re-fetch on event |
| `sentinelFlowPortalIntegrationTable` | `Integration_Health_Event__e` | Subscribes via `empApi`; triggers re-fetch on event |

**Existing Platform Events**:
- `Flow_Health_Event__e` — Emitted on Salesforce Flow failures (fields: `Flow_API_Name__c`, `Error_Message__c`, `Severity__c`, `Tenant__c`, `Affected_Records__c`)
- `Integration_Health_Event__e` — Emitted on integration health changes (fields: `API_Name__c`, `Status__c`, `Error_Message__c`, `Environment__c`, `Response_Time__c`, `Integration_Log_Id__c`)

Both are configured as `HighVolume` with `PublishAfterCommit` behavior.

---

## 3. Problem with Polling

### 3.1 Latency Gap
With a 30-second interval, operators see incident updates **0–30 seconds late**. For critical incidents entering the Guardian Gate, this delay can mean the difference between a 5-minute resolution and a 35-minute resolution.

### 3.2 API Consumption
Each poll cycle executes ~9-11 SOQL queries via a cacheable Apex method. With `N` concurrent dashboard users:

| Users | Polls/hour | SOQL queries/hour | API calls/hour |
|---|---|---|---|
| 1 | 120 | ~1,200 | 120 |
| 5 | 600 | ~6,000 | 600 |
| 10 | 1,200 | ~12,000 | 1,200 |
| 25 | 3,000 | ~30,000 | 3,000 |

At scale (25+ concurrent users), polling consumes a significant fraction of the Salesforce org's 100,000-call/24-hour API limit and 100 SOQL queries/transaction governor limit pressure.

### 3.3 Redundant Fetches
Most poll cycles return **identical data** because no incidents changed state. The `cacheable=true` wire adapter helps (Lightning Data Service caches responses), but the Apex call is still invoked server-side on every `refreshApex()`.

### 3.4 No Selective Refresh
Polling re-fetches the **entire** dashboard payload even when only one incident changed. There is no mechanism to push only the delta.

---

## 4. Proposed Streaming Architecture

### 4.1 Hybrid Model: Stream + Poll

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HYBRID STREAMING ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐                                               │
│  │  Apex Trigger /   │──► EventBus.publish()                        │
│  │  Future / Batch   │    ┌──────────────────────────────┐          │
│  └──────────────────┘    │ SentinelFlow_Dashboard_Event__e │          │
│                          │  • Incident_Id__c             │          │
│                          │  • Event_Category__c          │          │
│                          │  • Event_Action__c            │          │
│                          │  • Summary_Json__c            │          │
│                          │  • Tenant_Id__c               │          │
│                          └──────────┬───────────────────┘          │
│                                     │                               │
│                          ┌──────────▼───────────────────┐          │
│                          │     empApi (CometD/gRPC)      │          │
│                          │  /event/SentinelFlow_         │          │
│                          │  Dashboard_Event__e           │          │
│                          └──────────┬───────────────────┘          │
│                                     │                               │
│  ┌──────────────────┐    ┌──────────▼───────────────────┐          │
│  │  zentomDashboard  │◄──│   StreamingTelemetryMixin     │          │
│  │      (LWC)        │    │   • subscribe on connect     │          │
│  │                    │    │   • refreshApex on event     │          │
│  │  setInterval(60s)  │    │   • debounce rapid events    │          │
│  │  (fallback poll)   │    │   • error → resume polling   │          │
│  └──────────────────┘    └──────────────────────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Event granularity | One unified event (`SentinelFlow_Dashboard_Event__e`) | Reduces CometD subscription count; uses `Event_Category__c` for routing |
| Trigger-side publishing | Publish from existing triggers + dispatcher | Events fire only on meaningful state changes (not every field edit) |
| LWC subscription | `lightning/empApi` subscribe | Already proven in 4 Portal LWC components |
| Refresh strategy | Event triggers `refreshApex()` (full payload) | Keeps Apex controller unchanged; avoids partial state bugs |
| Polling interval change | Extend from 30s → 60s (fallback only) | Streaming handles real-time; polling catches missed events |
| Debounce | 2-second debounce window in LWC | Prevents rapid event bursts from hammering the server |

---

## 5. Platform Event Candidates

### 5.1 New Platform Event: `SentinelFlow_Dashboard_Event__e`

A single, unified dashboard event carrying a lightweight notification payload:

| Field | Type | Length | Description |
|---|---|---|---|
| `Incident_Id__c` | Text | 18 | The `Sentinel_Incident__c` record ID (optional — null for bulk events) |
| `Event_Category__c` | Text | 50 | Category of change: `INCIDENT`, `APPROVAL`, `EXECUTION`, `AUDIT`, `HEALTH` |
| `Event_Action__c` | Text | 80 | Specific action: `CREATED`, `STATUS_CHANGED`, `APPROVED`, `REJECTED`, `EXECUTED`, `ESCALATED`, `ALERT_SENT` |
| `Summary_Json__c` | LongTextArea | 5000 | Optional JSON summary of the changed record (for future inline updates without re-fetch) |
| `Tenant_Id__c` | Text | 18 | Tenant context for multi-tenant filtering |

**Configuration**:
- `eventType`: `HighVolume` (supports up to 100K events/day on Enterprise Edition)
- `publishBehavior`: `PublishAfterCommit` (ensures event only fires if the DML transaction commits)

### 5.2 Event Publishing Points

Events should be published from these existing Apex code paths:

| Source | Trigger / Method | Event Category | Event Action |
|---|---|---|---|
| `SentinelIncidentTrigger` | After insert / update | `INCIDENT` | `CREATED`, `STATUS_CHANGED` |
| `SentinelIncidentTrigger` | Approval status → Pending | `APPROVAL` | `PENDING_APPROVAL` |
| `ZentomDashboardController.approveWorkflow()` | After approve DML | `APPROVAL` | `APPROVED` |
| `ZentomDashboardController.rejectWorkflow()` | After reject DML | `APPROVAL` | `REJECTED` |
| `ZentomDashboardController.executeApprovedAction()` | After execution DML | `EXECUTION` | `EXECUTED` |
| `SentinelFlowNotificationDispatcher` | After audit log insert | `AUDIT` | `ALERT_SENT` |
| `FlowFaultTrigger` (existing) | After flow failure | `HEALTH` | `FLOW_FAILURE` |

### 5.3 Existing Events — Reuse Strategy

| Existing Event | Current Use | Streaming Telemetry Use |
|---|---|---|
| `Integration_Health_Event__e` | Portal LWC subscription | **Keep as-is**. Additionally subscribe in `zentomDashboard` for integration health signals. |
| `Flow_Health_Event__e` | Published but not subscribed in dashboard | **Subscribe** in `zentomDashboard` for flow failure signals. |

---

## 6. LWC Subscription Approach

### 6.1 StreamingTelemetryMixin Pattern

Create a reusable JavaScript mixin/utility that encapsulates the streaming subscription logic, so any LWC can opt in:

```javascript
// streamingTelemetry.js (utility module)
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

const DASHBOARD_EVENT_CHANNEL = '/event/SentinelFlow_Dashboard_Event__e';
const DEBOUNCE_MS = 2000;

export function initStreaming(component, onEventCallback) {
    let _sub = null;
    let _debounceTimer = null;
    let _streamingActive = false;

    const handleEvent = (event) => {
        _streamingActive = true;
        if (_debounceTimer) clearTimeout(_debounceTimer);
        _debounceTimer = setTimeout(() => {
            onEventCallback(event);
        }, DEBOUNCE_MS);
    };

    subscribe(DASHBOARD_EVENT_CHANNEL, -1, handleEvent)
        .then(sub => { _sub = sub; })
        .catch(err => { console.warn('Streaming subscribe failed:', err); });

    onError(err => {
        console.error('Streaming error:', err);
        _streamingActive = false;
    });

    return {
        unsubscribe: () => {
            if (_sub) unsubscribe(_sub, () => {});
        },
        isStreamingActive: () => _streamingActive
    };
}
```

### 6.2 zentomDashboard Integration

```javascript
// In zentomDashboard.js connectedCallback():
connectedCallback() {
    // Streaming: subscribe to real-time events
    this._streaming = initStreaming(this, () => {
        refreshApex(this.wiredDashboard);
    });

    // Fallback polling: extended interval (60s instead of 30s)
    this._pollTimer = setInterval(() => {
        if (this.wiredDashboard) {
            refreshApex(this.wiredDashboard);
        }
    }, FALLBACK_POLL_INTERVAL_MS);
}

disconnectedCallback() {
    if (this._streaming) this._streaming.unsubscribe();
    if (this._pollTimer) clearInterval(this._pollTimer);
}
```

### 6.3 Components to Subscribe

| LWC Component | Current Refresh | After Streaming |
|---|---|---|
| `zentomDashboard` | 30s polling | **Stream + 60s fallback poll** |
| `sentinelFlowBetaAppShell` | Manual refresh | **Stream subscription for badge counts** |
| `zentomApprovalQueue` | Wire adapter | **Stream + refreshApex on APPROVAL events** |
| `zentomActionCenter` | Wire adapter | **Stream + refreshApex on EXECUTION events** |
| `zentomReplayTimeline` | Wire adapter | **Stream + refreshApex on AUDIT events** |
| `sentinelFlowPortalSummary` | empApi (existing) | **Keep existing + add dashboard event** |

---

## 7. Fallback Polling Strategy

> [!IMPORTANT]
> Polling is **never removed**. It is the guaranteed safety net.

### 7.1 Fallback Rules

| Condition | Behavior |
|---|---|
| Streaming connected successfully | Polling interval extended to 60s (from 30s) |
| Streaming subscription fails | Polling remains at 30s (original behavior) |
| Streaming error/disconnect mid-session | Polling interval reverts to 30s; auto-retry streaming subscription after 30s |
| Platform Event delivery delayed (>5s) | No action needed; next poll cycle catches up |

### 7.2 Adaptive Polling Logic

```javascript
const STREAMING_POLL_MS = 60000;  // 60s when streaming is active
const FALLBACK_POLL_MS  = 30000;  // 30s when streaming is down

get currentPollInterval() {
    return this._streaming?.isStreamingActive()
        ? STREAMING_POLL_MS
        : FALLBACK_POLL_MS;
}
```

### 7.3 Graceful Degradation Matrix

| Scenario | Streaming | Polling | User Experience |
|---|---|---|---|
| Normal operation | ✅ Active | 60s fallback | Near-instant updates |
| empApi subscription fails | ❌ Down | 30s active | Same as current v1.1.0 behavior |
| Platform Event quota exceeded | ❌ Down | 30s active | Same as current v1.1.0 behavior |
| Salesforce maintenance window | ❌ Down | 30s active | Same as current v1.1.0 behavior |
| LWC disconnected/reconnected | 🔄 Re-subscribes | Active during gap | Brief gap, then real-time resumes |

---

## 8. Governor Limit Considerations

### 8.1 Platform Event Limits

| Limit | Value (Enterprise Edition) | Our Expected Usage |
|---|---|---|
| Max events published/day | 100,000 | ~50–200 (low-volume ops platform) |
| Max event payload size | 1 MB per event | ~500 bytes per event (well under) |
| Max subscribers per event | 2,000 | ~5–25 concurrent dashboard users |
| CometD connections per user | 1 per browser tab | Standard behavior |
| Event retention | 72 hours (High Volume) | Sufficient for replay |

### 8.2 SOQL Impact Reduction

| Metric | Polling Only (Current) | Streaming + Fallback (Proposed) |
|---|---|---|
| Refreshes/hour (1 user) | 120 | ~20 event-triggered + 60 fallback = **~80** (33% reduction) |
| Refreshes/hour (10 users) | 1,200 | ~200 event-triggered + 600 fallback = **~800** (33% reduction) |
| Refreshes/hour (25 users) | 3,000 | ~500 event-triggered + 1,500 fallback = **~2,000** (33% reduction) |

> [!NOTE]
> The real win is that event-triggered refreshes happen only when data actually changes, not on a blind timer. In quiet periods (no incidents), streaming generates **zero** extra API calls while polling would still execute 120 calls/hour/user.

### 8.3 Trigger DML Limits

Publishing a Platform Event counts as a DML operation. Each trigger execution already has a 150 DML limit. Publishing 1 event per incident state change is negligible overhead.

### 8.4 `PublishAfterCommit` Safety

Using `PublishAfterCommit` ensures:
- Events are only published if the enclosing transaction commits successfully
- No phantom events from rolled-back transactions
- Event delivery is ordered within a single publish call

---

## 9. Security / Access Considerations

### 9.1 Platform Event Object Permissions

The `SentinelFlow_Dashboard_Event__e` Platform Event requires object-level permissions:

| Permission Set | Read | Create |
|---|---|---|
| `SentinelFlow_Admin` | ✅ | ✅ (triggers publish events) |
| `SentinelFlow_Operator` | ✅ | ❌ (only subscribes) |
| Standard User (dashboard viewer) | ✅ | ❌ |

### 9.2 FLS Enforcement

Platform Event fields do **not** enforce FLS by default. However, since our event payload contains only IDs, category enums, and summary text (no PII, no sensitive financial data), this is acceptable. The `Summary_Json__c` field should never include:
- Raw credentials or tokens
- Customer PII (names, emails, phone numbers)
- Full error stack traces with internal class paths

### 9.3 Tenant Isolation

The `Tenant_Id__c` field on the event enables future multi-tenant filtering. LWC subscribers can filter incoming events by tenant context:

```javascript
handleEvent = (event) => {
    const payload = event.data.payload;
    if (this.currentTenantId && payload.Tenant_Id__c !== this.currentTenantId) {
        return; // Ignore events from other tenants
    }
    this._triggerRefresh();
};
```

### 9.4 CometD Channel Security

Salesforce enforces object-level access on Platform Event subscriptions. Users without Read access to `SentinelFlow_Dashboard_Event__e` will receive an `empApi` subscription error, and the fallback polling mechanism will handle their data refresh.

---

## 10. Success Criteria

### 10.1 Functional Criteria

| # | Criterion | Measurement |
|---|---|---|
| 1 | Dashboard updates within 3 seconds of incident state change | Manual timing test |
| 2 | Approval transitions (Pending → Approved/Rejected) reflect instantly | LWC subscription fires `refreshApex` |
| 3 | Execution outcomes update dashboard without waiting for poll | Audit log verifies event published |
| 4 | Existing polling continues to work unchanged | Disable streaming, verify 30s poll still functions |
| 5 | No duplicate dashboard refreshes from stream + poll overlap | Debounce mechanism prevents double-refresh |
| 6 | Streaming failure degrades gracefully to polling | Kill CometD connection, verify polling takes over |

### 10.2 Performance Criteria

| # | Criterion | Target |
|---|---|---|
| 1 | API call reduction (quiet period) | ≥50% fewer calls vs. polling-only |
| 2 | API call reduction (active period) | ≥25% fewer calls vs. polling-only |
| 3 | Event publish latency | <1 second from DML commit to event delivery |
| 4 | No governor limit impact | 0 additional governor limit failures |
| 5 | Event payload size | <1 KB per event |

### 10.3 Safety Criteria

| # | Criterion | Validation |
|---|---|---|
| 1 | Polling is never removed | Code review: `setInterval` remains in `connectedCallback` |
| 2 | Streaming subscription failure is silent | No user-facing error toast; falls back to polling |
| 3 | `PublishAfterCommit` prevents phantom events | Test: roll back a DML, verify no event published |
| 4 | Existing Portal LWC streaming unaffected | Regression test: Portal summary, impact panel, tables |
| 5 | Permission set changes backward-compatible | Deployment validation against `astrosoft` org |

---

## Appendix A: Milestone 48 Breakdown

| Sub-Milestone | Scope |
|---|---|
| **48A** | Architecture Plan (this document) |
| **48B** | Platform Event Contract Design — create `SentinelFlow_Dashboard_Event__e` metadata |
| **48C** | LWC Subscription Design — implement `streamingTelemetry` utility + wire into `zentomDashboard` |
| **48D** | Fallback Polling Strategy — implement adaptive polling interval logic |
| **48E** | Security / Governor Limit Review — update permission sets, validate limits |
| **48F** | Prototype Validation — deploy to `astrosoft`, run streaming + fallback tests |
| **48G** | Streaming Telemetry Wrap-up — documentation, commit, tag |

---

## Appendix B: File Impact Summary

| File | Action | Description |
|---|---|---|
| `SentinelFlow_Dashboard_Event__e.object-meta.xml` | NEW | Platform Event definition |
| `SentinelFlow_Dashboard_Event__e/fields/*.xml` | NEW | Event fields (5 fields) |
| `zentomDashboard/zentomDashboard.js` | MODIFY | Add empApi subscription + adaptive polling |
| `zentomDashboard/streamingTelemetry.js` | NEW | Reusable streaming utility module |
| `SentinelIncidentTrigger.trigger` | MODIFY | Publish dashboard event on state changes |
| `SentinelFlowNotificationDispatcher.cls` | MODIFY | Publish event after audit log insert |
| `ZentomDashboardController.cls` | MODIFY | Publish event after approve/reject/execute DML |
| `SentinelFlow_Admin.permissionset-meta.xml` | MODIFY | Add `SentinelFlow_Dashboard_Event__e` permissions |
| `docs/streaming-telemetry-architecture-plan.md` | NEW | This document |
| `docs/maintenance.md` | MODIFY | Log milestone progress |
