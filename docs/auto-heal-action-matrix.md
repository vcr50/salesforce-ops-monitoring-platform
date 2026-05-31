# Auto-Heal Allowed / Blocked Action Matrix

This document provides a structured operational matrix defining which actions the Auto-Heal engine is allowed to perform, their associated risk levels, approval gates, rollback rules, and auditing requirements.

## 1. Action Matrix

| Action Name | Action Type | Risk Level | Allowed? | Approval Required? | Rollback Available? | Audit Required? | Notes / Operational Boundaries |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Create Case** | Standard DML | Low / Medium | **Yes** | No (for Low/Medium risk scores) | Yes | **Yes** | Creates a Salesforce `Case` record for support escalation. Bounded to one case per incident signature. |
| **Create Task** | Standard DML | Low | **Yes** | No | Yes | **Yes** | Creates a standard Salesforce SRE follow-up task. |
| **Recommend Runbook** | UI Read-Only | Low | **Yes** | No | No | **Yes** | Suggests a runbook to the operator on UI layouts; no DML is performed. |
| **Send Notification** | Callout | Low | **Yes** | No | No | **Yes** | Outbound slack, teams, or email alerts. Covered by callout limits safety gates. |
| **Retry Safe Integration** | Callout Retry | Medium / High | **Yes** | Yes (for High/Critical risk scores) | Yes | **Yes** | Replays a failed transaction or webhook callout. Governed by standard retry thresholds. |
| **Update SentinelFlow Status**| Internal DML | Low | **Yes** | No | Yes | **Yes** | Internal state transitions on `Sentinel_Incident__c` or `Sentinel_Prediction__c`. |
| **Disable Flow / Trigger** | Metadata Update | Critical | **No** | Mandatory | No | **Yes** | **BLOCKED**: Modifying active automation or deactivating Apex triggers is prohibited. |
| **Delete Records** | Destructive DML | Critical | **No** | Mandatory | No | **Yes** | **BLOCKED**: No `DELETE` operation on standard or custom object records is permitted. |
| **Modify Metadata** | Metadata Update | Critical | **No** | Mandatory | No | **Yes** | **BLOCKED**: Changing Apex classes, layouts, or Custom Settings via API or toolings is blocked. |
| **Change Permissions** | Security Update | Critical | **No** | Mandatory | No | **Yes** | **BLOCKED**: Modifying Profiles, Permission Sets, or Object/Field FLS is blocked. |
| **Mass Update Business Data** | Mass DML | Critical | **No** | Mandatory | No | **Yes** | **BLOCKED**: Bulk data modification of records outside of targeted transactional scope is blocked. |

---

## 2. Core Governance Rules
1. **Approval Path Enforcement**:
   - Risk levels mapped in the matrix dynamically trigger the appropriate approval layout (Low maps to immediate logs, Medium to policy sign-off, and High/Critical to mandatory **Guardian Gate** clearance).
2. **Safe Action Fallbacks**:
   - If an action requires approval but is not yet approved, the system falls back to **Recommend Runbook** and sends an advisory notification.
3. **No Approval Bypass**:
   - Any attempt to bypass approval loops or invoke a blocked action triggers an immediate security alert and registers an `Auto-Heal Action Failed` event in `Sentinel_Audit_Log__c`.
