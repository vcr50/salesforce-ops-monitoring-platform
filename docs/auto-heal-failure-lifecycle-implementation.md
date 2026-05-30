# Auto-Heal Rollback & Failure Lifecycle Implementation

## 1. Purpose
This document specifies the technical implementation details for standardizing the rollback strategy, failure lifecycles, timeout safeguards, retry constraints, and operator notification workflows of SentinelFlow's Auto-Heal execution engine. It aligns the design principles established in Milestone 60 with the concrete execution flow in Milestone 61.

---

## 2. Failure Status Lifecycle
When an Auto-Heal action fails during execution (due to a validation failure, timeout, or external integration issue):
1. **Execution Status (`Execution_Status__c`)**: Set to `'Failed'`.
2. **Incident Status (`Status__c`)**: Set to `'Approval Required'`.
3. **Approval Status (`Approval_Status__c`)**: Set to `'Pending Approval'`.
4. **Execution Result (`Execution_Result__c`)**: Captures the detailed exception message (abbreviated to fit within field size limits).

By resetting the `Status__c` to `'Approval Required'` and the `Approval_Status__c` to `'Pending Approval'`, the system gracefully routes the failed incident back into the Guardian Gate clearance queue for manual inspection and troubleshooting by a human operator.

---

## 3. Transaction Savepoint & Rollback
To enforce transactional atomicity across multi-step execution paths:
1. **Initialize Savepoint**: Before executing any DML actions, a savepoint is registered:
   ```apex
   System.Savepoint sp = Database.setSavepoint();
   ```
2. **Reversion on Exception**: The execution block is wrapped in a `try-catch` construct. If any part of the execution throws an exception, the system immediately reverts all database modifications:
   ```apex
   Database.rollback(sp);
   ```
3. **Rollback Audit Logging**: Following the rollback, the system writes a detailed GRC audit log entry on `Sentinel_Audit_Log__c` with:
   - `Event_Type__c` = `'AUTO_HEAL_FAILED'`
   - `Decision__c` = `'ROLLBACK_EXECUTED'` (or `'FAILURE'`)
   - `Response_Payload__c` = Captures the detailed exception message.

---

## 4. Timeout Handling
Integration timeouts and callout failures are handled gracefully:
- **Callout Safeguard**: Callouts (such as sending notifications or triggering third-party runbooks) are executed in separate asynchronous contexts or prior to savepoint registration to comply with Salesforce callout limits.
- **Exception Trap**: The try-catch block specifically identifies callout timeouts (e.g. `System.CalloutException` or messages containing `timeout`):
  - Sets the incident's `Execution_Status__c` to `'Failed'`.
  - Reverts database mutations via savepoint rollback.
  - Logs a `Sentinel_Audit_Log__c` record with `Decision__c` = `'TIMEOUT'`.
  - Triggers operator notification workflows.

---

## 5. Partial Failure Handling
If a multi-step recovery runbook (such as creating a Case and then assigning a Task) encounters a partial failure (e.g., the Task fails due to custom validation rules):
- The entire transaction is rolled back via `Database.rollback(sp)`.
- No orphan records (e.g. a Case without a linked Task, or vice versa) are committed.
- The parent incident's status fields transition to the failure state.
- An audit log detailing the partial failure is registered.

---

## 6. Manual Review State
The manual review state acts as the ultimate safety net for failed or blocked executions:
- Incidents that fail are automatically queued in the **Clearance Queue** on the LWC Command Center dashboard.
- Operators can review the linked prediction details, audit logs, and retry history, and manually resolve the underlying issue.
- Once fixed, they can trigger execution again by approving the incident.

---

## 7. Retry Ingestion & Exhaustion State
To prevent runaway loops that exhaust API limits or cause transaction storms:
- **Attempt Tracking**: The engine queries the `Sentinel_Audit_Log__c` table to count previous execution attempts:
  ```apex
  Integer attempts = [
      SELECT COUNT()
      FROM Sentinel_Audit_Log__c
      WHERE Incident__c = :incidentId
      AND Event_Type__c IN ('AUTO_HEAL_EXECUTED', 'AUTO_HEAL_FAILED')
  ];
  ```
- **Max Retry Limits**: Auto-Heal execution is capped at **3 attempts**.
- **Exhaustion Block**: If `attempts >= 3`, the engine aborts execution immediately:
  - Logs `Event_Type__c` = `'AUTO_HEAL_BLOCKED'` and `Decision__c` = `'RETRY_EXHAUSTED'`.
  - Throws an `AutoHealException` detailing retry exhaustion.
  - Locks the incident out of automated execution, requiring manual triage.

---

## 8. Operator Notification
Upon execution failure:
- The system calls `SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(new List<Id>{ incidentId })`.
- Since this is an asynchronous `@future` method, it sends outbound webhooks to Slack and Microsoft Teams without blocking the primary database transaction.
- If Slack/Teams channels are not configured or are down, it automatically falls back to routing email alerts to registered SRE groups.

---

## 9. Verification & Unit Tests
To verify all failure paths, the following test cases are implemented:
1. `testExecuteAction_RollbackOnError()`: Confirms database transaction savepoints roll back correctly on execution exceptions, leaving zero orphan records, and writing the failure audit log.
2. `testRetryExhaustionBlocked()`: Asserts that when an incident exceeds 3 execution attempts, subsequent execution calls are blocked and logged as `RETRY_EXHAUSTED`.
3. `testCalloutTimeoutHandling()`: Simulates a callout timeout, verifying that the database is rolled back, the incident transitions to the failure state, and a `TIMEOUT` audit log is created.
