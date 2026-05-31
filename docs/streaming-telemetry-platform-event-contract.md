# Streaming Telemetry — Platform Event Contract Design (Milestone 48B)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Design — Approved  
**Version**: 1.0  
**Depends on**: [Streaming Telemetry Architecture Plan (48A)](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/streaming-telemetry-architecture-plan.md)

---

## 1. Overview

This document defines the **contract** for the `SentinelFlow_Dashboard_Event__e` Platform Event — the single, unified event that powers real-time streaming telemetry across the SentinelFlow Command Center.

> [!IMPORTANT]
> **Payload rules**:
> - Keep payload small — only dashboard-safe fields
> - No raw payloads (request/response bodies)
> - No secrets, API keys, or tokens
> - No hidden AI reasoning text (raw model outputs)
> - No PII (customer names, emails, phone numbers)

---

## 2. Platform Event Definition

### Object Metadata

| Property | Value |
|---|---|
| **API Name** | `SentinelFlow_Dashboard_Event__e` |
| **Label** | SentinelFlow Dashboard Event |
| **Plural Label** | SentinelFlow Dashboard Events |
| **Event Type** | `HighVolume` |
| **Publish Behavior** | `PublishAfterCommit` |
| **Description** | Real-time streaming event emitted when SentinelFlow incident state changes. Powers dashboard live-refresh and reduces polling overhead. |
| **Deployment Status** | `Deployed` |

### Why HighVolume + PublishAfterCommit

- **HighVolume**: Supports up to 100K events/day (Enterprise Edition), 72-hour retention for replay, and scales beyond Standard Volume limits.
- **PublishAfterCommit**: Events are only delivered if the enclosing DML transaction commits successfully. Prevents phantom events from rolled-back transactions.

---

## 3. Field Contract

### 3.1 Field Definitions

| # | Field API Name | Label | Type | Length | Required | Description |
|---|---|---|---|---|---|---|
| 1 | `Event_Type__c` | Event Type | Text | 50 | ✅ | The event classification. See §4 for valid values. |
| 2 | `Incident_Id__c` | Incident ID | Text | 18 | ❌ | The 18-character Salesforce record ID of the `Sentinel_Incident__c`. Null for non-incident events (e.g., `DASHBOARD_REFRESH_REQUESTED`). |
| 3 | `Incident_Number__c` | Incident Number | Text | 30 | ❌ | The auto-number name field (e.g., `SI-000042`). Enables display without a follow-up query. |
| 4 | `Incident_Type__c` | Incident Type | Text | 80 | ❌ | The incident classification (e.g., `FLOW_FAILURE`, `INTEGRATION_ERROR`, `APEX_EXCEPTION`, `SECURITY_EVENT`). |
| 5 | `Risk_Level__c` | Risk Level | Text | 20 | ❌ | The risk classification: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`. |
| 6 | `Approval_Status__c` | Approval Status | Text | 40 | ❌ | Current approval state: `Pending Approval`, `Approved`, `Rejected`. |
| 7 | `Execution_Status__c` | Execution Status | Text | 40 | ❌ | Current execution state: `Not Started`, `Ready for Execution`, `Executed`, `Failed`. |
| 8 | `AI_Reasoning_Status__c` | AI Reasoning Status | Text | 40 | ❌ | AI processing state: `ACTIVE`, `COMPLETE`, `FAILED`. |
| 9 | `AI_Confidence__c` | AI Confidence | Number | 5,0 | ❌ | AI confidence score (0–100). Integer precision, no decimals. |
| 10 | `Environment__c` | Environment | Text | 30 | ❌ | Source environment: `production`, `sandbox`. |
| 11 | `Event_Source__c` | Event Source | Text | 80 | ✅ | The Apex class or trigger that published this event. Used for debugging and audit. |
| 12 | `Event_Timestamp__c` | Event Timestamp | DateTime | — | ✅ | The timestamp of the originating action (not the CometD delivery time). |
| 13 | `Message__c` | Message | Text | 255 | ❌ | A short, human-readable summary of what happened. Dashboard-safe only. |

### 3.2 Field Design Rationale

| Design Decision | Rationale |
|---|---|
| **Text fields instead of Lookups** | Platform Events cannot have lookup relationships. IDs are carried as text. |
| **`Incident_Number__c` separate from `Incident_Id__c`** | Avoids a SOQL query to resolve the auto-number name for display in toast/badge notifications. |
| **`Event_Source__c` required** | Critical for debugging which code path published an event and for audit trail correlation. |
| **`AI_Confidence__c` as Number(5,0)** | Integer precision matches the `Sentinel_Incident__c.AI_Confidence__c` field. No decimal needed. |
| **`Message__c` capped at 255 chars** | Keeps payload small. No room for raw stack traces or AI model outputs. |
| **No `Summary_Json__c` (removed from 48A)** | Replaced with explicit typed fields. JSON blobs create parsing overhead in LWC and are harder to validate. |

### 3.3 Payload Size Estimate

| Field | Avg. Bytes |
|---|---|
| `Event_Type__c` | ~20 |
| `Incident_Id__c` | 18 |
| `Incident_Number__c` | ~10 |
| `Incident_Type__c` | ~20 |
| `Risk_Level__c` | ~8 |
| `Approval_Status__c` | ~16 |
| `Execution_Status__c` | ~15 |
| `AI_Reasoning_Status__c` | ~8 |
| `AI_Confidence__c` | ~3 |
| `Environment__c` | ~10 |
| `Event_Source__c` | ~40 |
| `Event_Timestamp__c` | ~24 |
| `Message__c` | ~100 |
| **Total estimated payload** | **~292 bytes** |

Well under the 1 MB Platform Event payload limit.

---

## 4. Event Types

### 4.1 Event Type Enumeration

| Event Type | Category | Description | Primary Source |
|---|---|---|---|
| `INCIDENT_CREATED` | Incident | A new `Sentinel_Incident__c` record was inserted | `SentinelIncidentTrigger` |
| `RISK_UPDATED` | Incident | Risk level or risk score changed on an existing incident | `SentinelIncidentTrigger` |
| `APPROVAL_REQUIRED` | Approval | Incident entered the Guardian Gate (`Approval_Status__c` → `Pending Approval`) | `SentinelIncidentTrigger` |
| `APPROVED` | Approval | Incident was approved by a human operator | `ZentomDashboardController.approveWorkflow()` |
| `REJECTED` | Approval | Incident was rejected by a human operator | `ZentomDashboardController.rejectWorkflow()` |
| `ACTION_READY` | Execution | Incident is approved and ready for execution | `ZentomDashboardController.approveWorkflow()` |
| `ACTION_EXECUTED` | Execution | Approved action was executed and a Case was created | `ZentomDashboardController.executeApprovedAction()` |
| `CASE_CREATED` | Execution | A Case record was linked to the incident | `ZentomDashboardController.executeApprovedAction()` |
| `AI_TRACE_UPDATED` | AI | AI reasoning status or confidence score changed | `ZentomIncidentClient` |
| `ERROR_LOGGED` | Health | An error was logged in the audit trail or error log | Error logging service |
| `DASHBOARD_REFRESH_REQUESTED` | System | A manual or system-wide refresh signal (e.g., admin bulk import) | Admin tooling / scripts |

### 4.2 Event Type → Dashboard Widget Mapping

| Event Type | Dashboard Section Affected |
|---|---|
| `INCIDENT_CREATED` | KPI counters, Incidents table, Risk distribution |
| `RISK_UPDATED` | KPI counters, Incidents table, Risk distribution, Org Health |
| `APPROVAL_REQUIRED` | Pending Approvals count, Approval Queue, Org Health |
| `APPROVED` | Pending Approvals count, Approval Queue, Action Center |
| `REJECTED` | Pending Approvals count, Approval Queue, Rejected count |
| `ACTION_READY` | Action Center queue |
| `ACTION_EXECUTED` | Executed Actions count, Executions table, Cases table |
| `CASE_CREATED` | Cases Created count, Cases table |
| `AI_TRACE_UPDATED` | AI Signal widget, AI Confidence average |
| `ERROR_LOGGED` | Error Log count, Flight Recorder timeline |
| `DASHBOARD_REFRESH_REQUESTED` | All sections (full refresh) |

### 4.3 Event Type Categories for LWC Filtering

LWC subscribers can use the `Event_Type__c` prefix to selectively refresh only affected sections:

```javascript
const INCIDENT_EVENTS = ['INCIDENT_CREATED', 'RISK_UPDATED'];
const APPROVAL_EVENTS = ['APPROVAL_REQUIRED', 'APPROVED', 'REJECTED'];
const EXECUTION_EVENTS = ['ACTION_READY', 'ACTION_EXECUTED', 'CASE_CREATED'];
const AI_EVENTS = ['AI_TRACE_UPDATED'];
const SYSTEM_EVENTS = ['ERROR_LOGGED', 'DASHBOARD_REFRESH_REQUESTED'];
```

> [!NOTE]
> In Phase 1 (48C), all event types trigger a full `refreshApex()`. Selective section refresh is a future optimization for Phase 2.

---

## 5. Emit Sources

### 5.1 Source-to-Event Mapping

Each emit source publishes specific event types at well-defined code points:

---

#### Source 1: `SentinelIncidentTrigger`

**Trigger context**: `after insert`, `after update`

| Condition | Event Type | When |
|---|---|---|
| New incident inserted | `INCIDENT_CREATED` | `Trigger.isInsert` |
| `Approval_Status__c` changed to `Pending Approval` | `APPROVAL_REQUIRED` | `Trigger.isUpdate` + status transition check |
| `Risk_Level__c` or `Risk_Score__c` changed | `RISK_UPDATED` | `Trigger.isUpdate` + field change check |

**Example publish point** (after existing webhook dispatch logic):

```apex
// In SentinelIncidentTrigger.trigger — after insert block
List<SentinelFlow_Dashboard_Event__e> events = new List<SentinelFlow_Dashboard_Event__e>();
for (Sentinel_Incident__c inc : Trigger.new) {
    events.add(new SentinelFlow_Dashboard_Event__e(
        Event_Type__c = 'INCIDENT_CREATED',
        Incident_Id__c = inc.Id,
        Incident_Number__c = inc.Name,
        Incident_Type__c = inc.Incident_Type__c,
        Risk_Level__c = inc.Risk_Level__c,
        Environment__c = inc.Environment__c,
        Event_Source__c = 'SentinelIncidentTrigger',
        Event_Timestamp__c = System.now(),
        Message__c = 'New incident created: ' + inc.Name
    ));
}
if (!events.isEmpty()) {
    EventBus.publish(events);
}
```

---

#### Source 2: `ZentomDashboardController` Actions

**Methods**: `approveWorkflow()`, `rejectWorkflow()`, `executeApprovedAction()`

| Method | Event Type(s) | When |
|---|---|---|
| `approveWorkflow()` | `APPROVED` + `ACTION_READY` | After successful DML update |
| `rejectWorkflow()` | `REJECTED` | After successful DML update |
| `executeApprovedAction()` | `ACTION_EXECUTED` + `CASE_CREATED` | After Case insert and incident update |

**Example publish point**:

```apex
// In approveWorkflow() — after successful update
EventBus.publish(new SentinelFlow_Dashboard_Event__e(
    Event_Type__c = 'APPROVED',
    Incident_Id__c = inc.Id,
    Incident_Number__c = inc.Name,
    Approval_Status__c = 'Approved',
    Event_Source__c = 'ZentomDashboardController.approveWorkflow',
    Event_Timestamp__c = System.now(),
    Message__c = 'Incident approved by ' + approvedBy
));
```

---

#### Source 3: `ZentomIncidentClient` (Incident Creation Pipeline)

**Context**: After Zentom AI creates and classifies a new incident.

| Condition | Event Type | When |
|---|---|---|
| Incident created with AI classification | `INCIDENT_CREATED` | After insert DML |
| AI confidence or reasoning status set | `AI_TRACE_UPDATED` | After AI field population |

> [!NOTE]
> If `ZentomIncidentClient` inserts an incident that also fires `SentinelIncidentTrigger`, the trigger already publishes `INCIDENT_CREATED`. To avoid duplicates, the client should **not** publish `INCIDENT_CREATED` directly — let the trigger handle it. The client should only publish `AI_TRACE_UPDATED` if AI fields are populated in a separate DML.

---

#### Source 4: Action Center Execution

**Context**: `ZentomDashboardController.executeApprovedAction()`

| Condition | Event Type | When |
|---|---|---|
| Case created and incident updated | `ACTION_EXECUTED` | After Case + incident DML |
| Case number available | `CASE_CREATED` | Same transaction |

These are handled by Source 2 (`ZentomDashboardController`).

---

#### Source 5: Error Logging Service

**Context**: When errors are logged to `Sentinel_Audit_Log__c` or `Sentinel_Error_Log__c`.

| Condition | Event Type | When |
|---|---|---|
| Error audit log inserted with `Decision__c` in (`Failed`, `Error`, `Exception`) | `ERROR_LOGGED` | After audit log insert |

**Candidate locations**:
- `SentinelFlowNotificationDispatcher.cls` — when webhook delivery fails
- `RetryLogService.cls` — when retry operations are logged
- Any future error handler that writes to `Sentinel_Audit_Log__c`

---

## 6. Publishing Utility

To enforce consistency and the payload rules, all event publishing should go through a single utility method:

```apex
public class SentinelFlowEventPublisher {

    public static void publish(
        String eventType,
        Sentinel_Incident__c incident,
        String source,
        String message
    ) {
        SentinelFlow_Dashboard_Event__e event = new SentinelFlow_Dashboard_Event__e();
        event.Event_Type__c = eventType;
        event.Event_Source__c = source;
        event.Event_Timestamp__c = System.now();
        event.Message__c = abbreviate(message, 255);

        if (incident != null) {
            event.Incident_Id__c = incident.Id;
            event.Incident_Number__c = incident.Name;
            event.Incident_Type__c = incident.Incident_Type__c;
            event.Risk_Level__c = incident.Risk_Level__c;
            event.Approval_Status__c = incident.Approval_Status__c;
            event.Execution_Status__c = incident.Execution_Status__c;
            event.AI_Reasoning_Status__c = incident.AI_Reasoning_Status__c;
            event.AI_Confidence__c = incident.AI_Confidence__c;
            event.Environment__c = incident.Environment__c;
        }

        EventBus.publish(event);
    }

    public static void publishBulk(
        String eventType,
        List<Sentinel_Incident__c> incidents,
        String source,
        String message
    ) {
        List<SentinelFlow_Dashboard_Event__e> events = new List<SentinelFlow_Dashboard_Event__e>();
        for (Sentinel_Incident__c inc : incidents) {
            SentinelFlow_Dashboard_Event__e event = new SentinelFlow_Dashboard_Event__e();
            event.Event_Type__c = eventType;
            event.Incident_Id__c = inc.Id;
            event.Incident_Number__c = inc.Name;
            event.Incident_Type__c = inc.Incident_Type__c;
            event.Risk_Level__c = inc.Risk_Level__c;
            event.Approval_Status__c = inc.Approval_Status__c;
            event.Execution_Status__c = inc.Execution_Status__c;
            event.AI_Reasoning_Status__c = inc.AI_Reasoning_Status__c;
            event.AI_Confidence__c = inc.AI_Confidence__c;
            event.Environment__c = inc.Environment__c;
            event.Event_Source__c = source;
            event.Event_Timestamp__c = System.now();
            event.Message__c = abbreviate(message, 255);
            events.add(event);
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    public static void publishSystemEvent(String eventType, String source, String message) {
        publish(eventType, null, source, message);
    }

    private static String abbreviate(String value, Integer maxLen) {
        if (value == null || value.length() <= maxLen) return value;
        return value.substring(0, maxLen);
    }
}
```

> [!IMPORTANT]
> **All event publishing MUST go through `SentinelFlowEventPublisher`**. Direct `EventBus.publish()` calls are prohibited outside this class. This ensures payload validation, field truncation, and consistent source tracking.

---

## 7. Deduplication Strategy

### 7.1 Trigger-Level Deduplication

The `SentinelIncidentTrigger` already performs status transition checks for webhook dispatch. The same pattern applies to event publishing:

| Scenario | Publish? | Reason |
|---|---|---|
| New incident inserted | ✅ `INCIDENT_CREATED` | Always publish on insert |
| Incident updated, `Approval_Status__c` changed to `Pending Approval` | ✅ `APPROVAL_REQUIRED` | State transition detected |
| Incident updated, `Approval_Status__c` unchanged | ❌ Skip | No meaningful state change |
| Incident updated, `Risk_Level__c` changed | ✅ `RISK_UPDATED` | Risk classification changed |
| Incident updated, only `Description__c` changed | ❌ Skip | Not a dashboard-relevant change |

### 7.2 LWC-Level Deduplication

The LWC debounce mechanism (2-second window from 48A) prevents multiple rapid events from causing multiple `refreshApex()` calls. Additionally, `refreshApex()` itself is idempotent — calling it twice with unchanged data returns the cached response.

---

## 8. CometD Channel

### 8.1 Subscription Channel

```
/event/SentinelFlow_Dashboard_Event__e
```

### 8.2 Replay ID Strategy

| Strategy | Value | Behavior |
|---|---|---|
| Latest only | `-1` | Receive only new events from subscription time forward |
| Replay from ID | `{replayId}` | Receive events from a specific replay ID (72-hour window) |
| All retained | `-2` | Receive all events in the 72-hour retention window |

**Recommendation**: Use `-1` (latest only) for dashboard subscriptions. The fallback polling mechanism handles any events missed during subscription setup.

---

## 9. Payload Examples

### 9.1 `INCIDENT_CREATED` Event

```json
{
  "Event_Type__c": "INCIDENT_CREATED",
  "Incident_Id__c": "a01dL000005XYZABC",
  "Incident_Number__c": "SI-000042",
  "Incident_Type__c": "INTEGRATION_ERROR",
  "Risk_Level__c": "HIGH",
  "Approval_Status__c": null,
  "Execution_Status__c": "Not Started",
  "AI_Reasoning_Status__c": "ACTIVE",
  "AI_Confidence__c": 78,
  "Environment__c": "production",
  "Event_Source__c": "SentinelIncidentTrigger",
  "Event_Timestamp__c": "2026-05-29T10:15:00.000Z",
  "Message__c": "New incident created: SI-000042"
}
```

### 9.2 `APPROVED` Event

```json
{
  "Event_Type__c": "APPROVED",
  "Incident_Id__c": "a01dL000005XYZABC",
  "Incident_Number__c": "SI-000042",
  "Incident_Type__c": "INTEGRATION_ERROR",
  "Risk_Level__c": "HIGH",
  "Approval_Status__c": "Approved",
  "Execution_Status__c": "Ready for Execution",
  "AI_Reasoning_Status__c": "COMPLETE",
  "AI_Confidence__c": 92,
  "Environment__c": "production",
  "Event_Source__c": "ZentomDashboardController.approveWorkflow",
  "Event_Timestamp__c": "2026-05-29T10:18:30.000Z",
  "Message__c": "Incident approved by Admin User"
}
```

### 9.3 `DASHBOARD_REFRESH_REQUESTED` System Event

```json
{
  "Event_Type__c": "DASHBOARD_REFRESH_REQUESTED",
  "Incident_Id__c": null,
  "Incident_Number__c": null,
  "Incident_Type__c": null,
  "Risk_Level__c": null,
  "Approval_Status__c": null,
  "Execution_Status__c": null,
  "AI_Reasoning_Status__c": null,
  "AI_Confidence__c": null,
  "Environment__c": null,
  "Event_Source__c": "AdminBulkImportScript",
  "Event_Timestamp__c": "2026-05-29T10:20:00.000Z",
  "Message__c": "Bulk incident import completed. Dashboard refresh requested."
}
```

---

## 10. Security Checklist

| # | Rule | Status |
|---|---|---|
| 1 | No raw request/response payloads in `Message__c` | ✅ Enforced by 255-char limit |
| 2 | No API keys, secrets, or tokens in any field | ✅ No credential fields defined |
| 3 | No hidden AI reasoning text (raw model outputs) | ✅ Only status enum + integer confidence |
| 4 | No PII (customer names, emails, phone numbers) | ✅ Only system identifiers and enums |
| 5 | `Event_Source__c` contains only class/method names | ✅ Enforced by publisher utility |
| 6 | `SentinelFlow_Admin` permission set grants Read + Create | ⬜ To implement in 48E |
| 7 | Standard users get Read-only access | ⬜ To implement in 48E |

---

## 11. Compatibility with Existing Platform Events

| Existing Event | Conflict Risk | Resolution |
|---|---|---|
| `Flow_Health_Event__e` | None | Different event, different channel. Dashboard can optionally subscribe to both. |
| `Integration_Health_Event__e` | None | Different event, different channel. Portal components keep existing subscriptions. |

The new `SentinelFlow_Dashboard_Event__e` does **not** replace existing events. It is an additive, dashboard-specific event channel.

---

## 12. Implementation Checklist (for 48B Metadata)

> [!NOTE]
> This section defines **what to build** in the implementation phase. The metadata files listed here will be created when the architecture moves from design to code.

- [ ] `SentinelFlow_Dashboard_Event__e.object-meta.xml`
- [ ] `fields/Event_Type__c.field-meta.xml`
- [ ] `fields/Incident_Id__c.field-meta.xml`
- [ ] `fields/Incident_Number__c.field-meta.xml`
- [ ] `fields/Incident_Type__c.field-meta.xml`
- [ ] `fields/Risk_Level__c.field-meta.xml`
- [ ] `fields/Approval_Status__c.field-meta.xml`
- [ ] `fields/Execution_Status__c.field-meta.xml`
- [ ] `fields/AI_Reasoning_Status__c.field-meta.xml`
- [ ] `fields/AI_Confidence__c.field-meta.xml`
- [ ] `fields/Environment__c.field-meta.xml`
- [ ] `fields/Event_Source__c.field-meta.xml`
- [ ] `fields/Event_Timestamp__c.field-meta.xml`
- [ ] `fields/Message__c.field-meta.xml`
- [ ] `SentinelFlowEventPublisher.cls`
- [ ] `SentinelFlowEventPublisherTest.cls`
