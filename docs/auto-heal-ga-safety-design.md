# Auto-Heal GA Safety Plan

## 1. Purpose
This document defines the safety boundaries, operational limits, human-in-the-loop governance policies, rollback strategies, security compliance rules, and emergency kill switches required to transition SentinelFlow's Auto-Heal capabilities into a General Availability (GA) state. The goal is to ensure that automated remediation actions are enterprise-safe, audited, and strictly controlled.

---

## 2. Current Auto-Heal Model
Currently, SentinelFlow features a reactive self-healing engine (`SelfHealingEngine.cls`) that processes inbound telemetry, assesses incident signatures, maps actions, and triggers auto-healing.
- **Limitation**: Direct execution of recovery steps lacks mandatory governance check gates at critical risk levels.
- **Objective for GA**: Introduce a policy-controlled gate where the Prediction Engine recommends, policies evaluate risk, human approval controls execution, and audit logs record all decisions.

---

## 3. GA Safety Requirements
To protect enterprise production environments, the Auto-Heal GA implementation must guarantee:
1. **Zero-Harm Execution**: Automated actions cannot destructively modify business records or change system configurations.
2. **Deterministic Behavior**: A given incident signature always maps to a predictable, bounded set of actions. No random or dynamic AI-generated DML executions.
3. **Execution Gating**: Gated by a global emergency stop switch and duplicate execution guards.
4. **Governor Limit Compliance**: Strict CPU, Heap, and DML limits checks prior to triggering any operation.

---

## 4. Allowed Actions
Only the following safe, non-destructive actions are permitted for autonomous or policy-governed Auto-Heal execution:
- **Create Case**: Creating a standard Salesforce `Case` record to escalate issues to support teams.
- **Create Task**: Creating a standard `Task` for SRE or Admin follow-up.
- **Recommend Runbook**: Presenting suggested diagnostic runbooks on incident/prediction layouts.
- **Send Notification**: Dispatched outbound webhooks to Slack, Teams, or email notification channels.
- **Retry Safe Integration**: Attempting a replay or retry of a failed transactional callout/integration (e.g. failed outbound webhook) using standard retry limits.
- **Update Internal SentinelFlow Status**: Modifying fields on custom operational objects (`Sentinel_Incident__c`, `Sentinel_Prediction__c`) to transition status or record logs.

---

## 5. Blocked Actions
The following actions are strictly prohibited from being performed by the Auto-Heal engine:
- **Delete Records**: Under no circumstances will Auto-Heal perform a `DELETE` operation on any custom or standard Salesforce records.
- **Mass Update Business Records**: Mass updating records outside of the targeted transactional retry scope is blocked.
- **Change Permissions**: Modifying Profiles, Permission Sets, or Object/Field permissions is blocked.
- **Modify Metadata**: Direct or indirect updates to metadata components (Apex classes, Flows, triggers, custom settings) are blocked.
- **Disable Flows/Triggers**: Deactivating active operational logic is blocked.
- **Execute Destructive Deployment**: Triggering metadata deployments or packages is blocked.
- **Bypass Approval**: Bypassing configured risk policies or human-in-the-loop review criteria is blocked.

---

## 6. Human Approval Rules
Human-in-the-loop remains the primary security boundary. Operational risk controls the approval path:
1. **Low Risk (Score < 40%)**:
   - Recommendation only, or safe actions (e.g. notifications, status logs) if policy settings allow autonomous execution.
2. **Medium Risk (Score 40% - 69%)**:
   - Mandatory Policy Approval required. Evaluated by internal compliance gates or signed off by an authorized operator.
3. **High/Critical Risk (Score >= 70%)**:
   - Mandatory human approval via the **Guardian Gate** queue before any action is executed. No autonomous execution allowed.

---

## 7. Risk Thresholds
The risk level of predicted anomalies or incidents maps to the following governance gates:
| Risk Level | Risk Score Range | Governance Gate Requirement | Execution Path |
| :--- | :--- | :--- | :--- |
| **Low** | `0% - 39%` | Log Advisory | Recommendation only / Auto-Notify |
| **Medium** | `40% - 69%` | Policy Review | Policy Action requires operator sign-off |
| **High** | `70% - 89%` | Guardian Gate Queue | Mandatory Human Approve/Reject |
| **Critical** | `90% - 100%` | Guardian Gate Queue | Mandatory Human Approve/Reject |

---

## 8. Rollback Strategy
To maintain consistency during failures:
1. **Database Savepoints**: Every Auto-Heal execution block must wrap its database operations inside a Salesforce database savepoint (`Database.setSavepoint()`). If any part of the operation fails, the transaction is completely rolled back to the savepoint to prevent partial states.
2. **State Reversion**: If an executed runbook creates downstream issues, SRE operators must be able to toggle a "Revert Runbook" state on the incident, triggering a compensating action (e.g. closing generated support cases or logging cancellation audit events).

---

## 9. Audit Requirements
Every operational decision and action outcome must be recorded as an audit event in `Sentinel_Audit_Log__c`:
- **Traceability**: Audit events must link to the parent `Sentinel_Incident__c` and log the initiating `User` or system actor.
- **Action Outcomes**: Successfully executed actions must log `Success` with execution timestamps.
- **Execution Failures**: Failed executions must capture the error message, stack trace, and rollback confirmation.
- **Audit Event Types**:
  - `Auto-Heal Initiated`
  - `Auto-Heal Safe-Retry Success`
  - `Auto-Heal Action Failed`
  - `Auto-Heal Transaction Rolled Back`
  - `Auto-Heal Emergency Stop Triggered`

---

## 10. Security / CRUD / FLS Rules
The Auto-Heal engine must strictly execute in a user-sharing context, adhering to Salesforce platform security models:
- **Enforced FLS & CRUD**: All queries and DML updates inside the engine must use security clauses (`WITH USER_MODE`, `Security.stripInaccessible()`, or explicit `isCreateable()`/`isUpdateable()` checks).
- **Access Checklist**:
  - [ ] `Sentinel_Incident__c` CRUD (Create/Read/Edit) is required for execution logs.
  - [ ] `Sentinel_Prediction__c` CRUD is required to propagate feedback decisions.
  - [ ] `Sentinel_Audit_Log__c` Create/Read permissions are required for auditing.
  - [ ] Standard objects (`Case`, `Task`) must enforce FLS on creation.

---

## 11. Failure Handling & Core Safety Gates
To prevent cascading failures:
1. **Emergency Kill Switch**:
   - A global custom metadata setting `Auto_Heal_Active__c` acts as the master circuit breaker. If set to `false`, the engine immediately aborts all active auto-heal runs and degrades to advisory notifications only.
2. **Duplicate Execution Prevention**:
   - Before executing an action, the engine must lock the parent incident (`SELECT FOR UPDATE`) and verify `Execution_Status__c` is not already `Executed` or `In Progress`.
3. **Partial Failure Handling**:
   - Any unhandled exception during execution is caught, logged to `Sentinel_Audit_Log__c`, and triggers a complete database rollback. No orphaned cases or tasks.
4. **Governor Limit Safety**:
   - The engine must check `Limits.getDMLRows()`, `Limits.getDMLStatements()`, and `Limits.getCpuTime()` prior to executing any DML or API callouts. If remaining resource headroom is below 15%, execution is aborted and logged.

---

## 12. Go / No-Go Criteria
Before the Auto-Heal GA implementation is promoted to production, the following criteria must be satisfied:
- **Unit Test Coverage**: $\ge 95\%$ coverage across all Auto-Heal service classes with assertions validating savepoint rollbacks and duplicate execution blockades.
- **Static Security Scan**: Zero high-severity security findings (e.g. SOQL injection, CRUD/FLS bypasses) in static analysis.
- **Manual QA Execution**: Successful dry-run and commit validation across timeout and retry scenarios in the sandbox.
- **Kill Switch Validation**: Verified that disabling the master `Auto_Heal_Active__c` toggle halts all operational actions immediately.
