# Auto-Heal GA Implementation Plan

## 1. Purpose
This document provides the technical implementation blueprint for translating SentinelFlow's Auto-Heal safety rules (established in Milestone 60) into code. The goal is to construct a governed operational execution engine that automates recovery actions safely under strict GRC and human-in-the-loop limits.

---

## 2. Implementation Scope
The following components and source files are within the scope of this implementation sprint:
- **`AutoHealExecutionService.cls`**: Central coordinator class handling execution limits and status updates.
- **`AllowedActionExecutor.cls`**: Core execution module responsible for safe integrations (Cases, Tasks, Notifications, status updates).
- **Custom Metadata Settings**: Creating new settings fields on `SentinelFlow_Setting__mdt` for kill switches and SLA timers.
- **LWC Dashboard Alerts**: Adding visual timeout warnings to the Clearance Queue grid.
- **`SentinelIncidentTrigger.trigger`**: Activating lookup synchronization and automatic reversion loops.

---

## 3. Safety Controls from Milestone 60
The Apex runtime will programmatically assert safety checkpoints at each step:
- **Pre-execution limits gate**: Asserts that `Limits.getDMLStatements()` and CPU margins have $\ge 15\%$ headroom.
- **Duplicate execution guard**: Enforces database-level `FOR UPDATE` row locks.
- **Strict User Mode**: Enforces `WITH USER_MODE` or `Security.stripInaccessible()` on DML queries.

---

## 4. Allowed Action Execution Design
Safe operations will be dispatched via a structured executor module:
1. **DML Actions (Create Case / Task)**: Enforces Field-Level Security on standard objects prior to insert.
2. **Alert Callouts (Slack / Teams)**: Executed in an asynchronous queueable context (`@future` or `System.enqueueJob`) to avoid blocking transactions.
3. **Safe Retries**: Covered by a sliding window database counter to prevent retry loops from exceeding 3 attempts.

---

## 5. Blocked Action Enforcement
To guarantee blocked actions are never executed:
- **Static Guards**: The executor explicitly maps action codes. If an action type is requested that matches `Delete Records`, `Disable Flow`, `Modify Metadata`, or `Change Permissions`, the service throws a `GovernanceException` and halts the transaction.
- **DML Validation Rules**: Database-level triggers prevent any delete operation on incidents or audit logs.

---

## 6. Guardian Gate Integration
For high and critical-risk scenarios:
- **Approval Hold**: The engine creates an incident record with `Approval_Status__c = 'Pending Approval'` and exits.
- **Clearance Hook**: When an SRE grants approval via the Guardian Gate, `ZentomDashboardController.approveWorkflow` updates the status to `Approved`, which programmatically triggers the `AutoHealExecutionService` to execute the runbook.

---

## 7. Rollback Implementation
- **Transaction Savepoints**: Every run is wrapped inside an Apex `Database.setSavepoint()` block.
- **Compensating Actions**: In the `catch` block, `Database.rollback()` is executed, and the error state is propagated to the UI.

---

## 8. Audit Logging Implementation
- **Log Generator**: The `logAuditEvent` helper creates read-only records in `Sentinel_Audit_Log__c`.
- **Trace UUID**: A static UUID parameter is shared across the transaction context to group all logs of a single execution thread.

---

## 9. Kill Switch Implementation
- **Custom Metadata Guard**:
  ```apex
  Boolean isActive = SystemSettings.getBoolean('Auto_Heal_Active', true);
  if (!isActive) {
      // Abort execution, log to audit trail, notify operators
      return;
  }
  ```

---

## 10. Test Strategy
- **Unit Test Cases**:
  - `testSavepointRollbackOnException`: Verifies database is completely clean after a failure.
  - `testDuplicateExecutionGuard`: Asserts that concurrent attempts exit cleanly.
  - `testKillSwitchActive`: Verifies deactivation stops all actions.
- **Coverage Target**: $\ge 95\%$ on all newly added Apex classes.

---

## 11. Deployment Plan
- Deploy metadata and classes to dev sandbox `vjdev@asap.com`.
- Run full regression test suites.
- Perform a manual pilot run using scenario simulations.

---

## 12. Success Criteria
1. **No Destructive Operations**: Confirm that blocked actions (e.g. deactivations, deletions) throw runtime errors.
2. **Atomic Rollback Verification**: Confirm that partial failures result in a clean state with zero orphan tasks.
3. **Kill Switch Enforcement**: Confirm that setting the metadata flag to false immediately stops execution.
