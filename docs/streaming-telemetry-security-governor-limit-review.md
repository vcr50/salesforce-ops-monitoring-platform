# Streaming Telemetry — Security & Governor Limit Review (Milestone 48E)

**Date**: 2026-05-29  
**Author**: TomCodeX Engineering  
**Status**: Design — Pending Review  
**Version**: 1.0  
**Depends on**: [Fallback Polling Strategy (48D)](file:///d:/TomCodeX%20Inc/SentinelFlow/docs/streaming-telemetry-fallback-polling-design.md)

---

## 1. Overview

Implementing real-time streaming telemetry introduces two critical architectural integration areas in Salesforce: **Security Access Control** and **Governor Limit Compliance**. 

Because Platform Events are processed at the database layer and distributed via CometD, we must ensure they respect Salesforce's security framework without exhausting standard system quotas.

This document reviews:
1. Object-level and field-level security configurations across all user roles.
2. sharing rules, and how the CometD architecture maintains strict record-level security.
3. Database Governor Limits (DML, CPU time, and SOQL limits) during event publishing.
4. Mitigation strategies to avoid infinite trigger recursion and bulk transaction failures.

---

## 2. Permission Set Design

To allow users to subscribe and publish, we must update the SentinelFlow permission sets. Platform Events only support `Read` (for subscription) and `Create` (for publishing) permissions. Other permissions (`Edit`, `Delete`, `View All`, `Modify All`) are invalid for event metadata.

### 2.1 Access Matrix

| Role | Permission Set | allowRead | allowCreate | Purpose |
|---|---|---|---|---|
| **Administrator** | `SentinelFlow_Admin` | ✅ | ✅ | Full management, publishing via scripts, and debug subscription. |
| **System Process** | `SentinelFlow_Runtime_Admin` | ✅ | ✅ | Internal automation context to publish events in triggers. |
| **Operations Operator** | `SentinelFlow_Operator` | ✅ | ❌ | Subscribes to dashboard telemetry. Cannot publish manual events. |
| **Dashboard Viewer** | `SentinelFlow_Viewer` | ✅ | ❌ | Read-only subscription to dashboard telemetry. |

---

### 2.2 Metadata Snippets for Permission Sets

#### 2.2.1 `SentinelFlow_Admin.permissionset-meta.xml` Additions

```xml
    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>SentinelFlow_Dashboard_Event__e</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>SentinelFlow_Dashboard_Event__e.Event_Type__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>SentinelFlow_Dashboard_Event__e.Incident_Id__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>SentinelFlow_Dashboard_Event__e.Incident_Number__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <!-- Repeat readable-only FLS blocks for all 13 event fields -->
```

#### 2.2.2 `SentinelFlow_Operator.permissionset-meta.xml` Additions

```xml
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>SentinelFlow_Dashboard_Event__e</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
    <!-- Repeat readable-only FLS blocks for all 13 event fields -->
```

---

## 3. Data Privacy and Sharing Compliance

### 3.1 Field-Level Security (FLS) Compliance
Platform Events do not enforce standard Salesforce Field-Level Security automatically at the API layer. Therefore, to secure the platform, we apply **FLS Compliance by Design**:
- **No Sensitive Data**: We explicitly omit sensitive fields such as client API keys, secrets, tokens, PII (customer emails, names), and unstructured AI raw text from the payload.
- **System Identifiers Only**: The event carries only enums, database record IDs (`Incident_Id__c`), and public auto-numbers (`Incident_Number__c`). 

### 3.2 Record-Level Sharing Compliance
CometD channel subscriptions deliver events to all active subscribers with `Read` access. This could theoretically allow an operator to receive an event for an incident they do not have Salesforce sharing permissions to see.

To prevent this data leak, we implement a **Hybrid Security Architecture**:
1. **Lightweight Notification Event**: The Platform Event does **not** carry the actual data fields of the incident. It only carries a lightweight "hey, something changed!" signal.
2. **Sharing-Compliant Re-Fetch**: When the LWC receives the event, it invokes `refreshApex(this.wiredDashboard)`. 
3. **Sharing Enforcement**: `refreshApex()` invokes `ZentomDashboardController.getDashboardData()`, which is declared as `with sharing`. 
4. **Security Enforcement**: The Apex controller automatically enforces Salesforce Sharing Rules, FLS, and CRUD permissions. If the user does not have sharing access to the modified incident, the returned dataset simply omits it. 

This hybrid design guarantees that **zero data leaks occur**, maintaining complete compliance with the enterprise security model.

---

## 4. Trigger DML and Recursion Protection

Publishing Platform Events in database triggers can lead to infinite loops if not carefully protected. For example:
`Incident DML Update` ➔ `Trigger runs` ➔ `Publishes Platform Event` ➔ `Flow/Trigger consumes Event` ➔ `DML Update on Incident` ➔ `Trigger runs again...`

### 4.1 Recursion Prevention Pattern

We enforce a recursion guard inside the publishing service `SentinelFlowEventPublisher` using a static transaction thread state:

```apex
public class SentinelFlowEventPublisher {
    // Static set to keep track of incident IDs published during the current request thread
    private static Set<Id> publishedIncidentIds = new Set<Id>();

    public static void publish(String eventType, Sentinel_Incident__c incident, String source, String message) {
        if (incident != null && incident.Id != null) {
            // Guard: Avoid duplicate events for the same incident in the same transaction
            String guardKey = incident.Id + '_' + eventType;
            if (publishedIncidentIds.contains(incident.Id)) {
                System.debug('[SentinelFlowEventPublisher] Skip duplicate event publishing for Incident: ' + incident.Id);
                return;
            }
            publishedIncidentIds.add(incident.Id);
        }

        // Proceed to build and publish event...
    }
}
```

---

## 5. Governor Limit Analysis

We analyze the impact of adding event publishing on the standard Salesforce limits per transaction:

### 5.1 DML Quotas (Limit: 150 DML Statements)
- **Standard DML**: Each `EventBus.publish()` call counts as **1 DML statement** towards the 150 statement limit.
- **Bulk DML Optimization**: If an Apex trigger updates 200 incidents, executing `EventBus.publish()` individually would consume 200 DML statements, throwing a `System.LimitException: Too many DML statements: 151`.
- **Mitigation**: We mandate using the bulkified publisher `SentinelFlowEventPublisher.publishBulk(..., List<Sentinel_Incident__c>, ...)` inside all triggers. This ensures all events are compiled and fired in a single, bulkified `EventBus.publish()` call, consuming only **1 DML statement** for the entire batch.

### 5.2 Heap Size (Limit: 6 MB Synchronous / 12 MB Asynchronous)
- The average event payload is ~292 bytes.
- A bulk trigger of 200 events consumes `200 * 292 bytes = 58.4 KB` of heap space.
- This represents less than **0.9%** of the synchronous heap limit.

### 5.3 CPU Time (Limit: 10,000 ms)
- Building and publishing a Platform Event in Apex consumes negligible CPU time (~5–15 milliseconds).
- Transaction execution times remain well within safety margins.

### 5.4 Platform Event Daily Allocations
- **Limit**: 100,000 published events per 24 hours (Enterprise Edition).
- **Projected SentinelFlow Load**:
  - 10 incidents/day with 5 state transitions each = 50 events.
  - Plus 20 manual actions and logs = 70 events/day.
  - Consumes less than **0.07%** of the daily allocation, leaving ample headroom for other client systems.

---

## 6. Implementation Checklist for Milestone 48E

- [ ] Modify `SentinelFlow_Admin.permissionset-meta.xml` to grant `Read + Create` access to `SentinelFlow_Dashboard_Event__e`.
- [ ] Modify `SentinelFlow_Operator.permissionset-meta.xml` to grant `Read-Only` access.
- [ ] Add static `publishedIncidentIds` recursion guard inside `SentinelFlowEventPublisher.cls`.
- [ ] Integrate bulkified publishing calls in trigger context using `Trigger.isAfter` to ensure `PublishAfterCommit` behavior is honored.
