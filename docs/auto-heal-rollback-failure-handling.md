# Rollback Strategy & Failure Handling Design

## 1. Purpose
This document defines the database transaction boundaries, rollback mechanisms, retry constraints, and error recovery lifecycles for SentinelFlow's Auto-Heal engine during General Availability (GA). The design ensures that any failure, timeout, or partial success results in a deterministic, safe state, preventing data corruption and orphaned records.

---

## 2. Rollback Principles
To ensure system safety, the Auto-Heal engine operates under three core rollback principles:
- **Atomicity**: Any automated operations must execute as a single, indivisible unit. If one step fails, the entire transaction must be reverted.
- **Consistency**: Database state transitions must never leave orphaned records (e.g. an incident marked "Executed" without its corresponding Salesforce Case being successfully inserted).
- **Safety Fallback**: If an operation cannot be completed safely, it must abort immediately, revert its changes, notify operators, and delegate the issue to human triage.

---

## 3. Transaction Savepoint Strategy
All Auto-Heal DML executions must leverage Salesforce Database Savepoints:
1. **Initialize Savepoint**: Before executing any DML or record modifications, the engine sets a savepoint:
   ```apex
   System.Savepoint sp = Database.setSavepoint();
   ```
2. **Try-Catch Wrapping**: The entire operational block is wrapped in a `try-catch` structure.
3. **Reversion on Error**: In the `catch` block, the system explicitly rolls back all database modifications:
   ```apex
   Database.rollback(sp);
   ```
4. **Callout Isolation**: Because callouts cannot be executed after setting a savepoint, the engine must execute all callouts (e.g. notifications, retry integrations) *before* initializing the database savepoint, or run them in separate asynchronous contexts.

---

## 4. Partial Failure Handling
Multi-step recovery runbooks (e.g. Notify SRE → Create Case → Assign Task) are vulnerable to partial failures.
- **Strict Abort**: If any intermediate step fails (e.g., Task creation fails due to validation rules), the engine invokes the `Database.rollback(sp)` routine, undoing all prior steps (e.g., deleting the created Case).
- **Graceful Degradation**: The incident's `Execution_Status__c` transitions to `Failed`, and a standard manual runbook suggestion is displayed to guide SREs through manual resolution.

---

## 5. Retry Limits
To prevent infinite loops and API resource exhaustion:
- **Maximum Retries**: Safe retries for integrations or transactional webhooks are capped at a maximum of **3 attempts**.
- **Exponential Backoff**: Retries must adhere to an exponential delay pattern (e.g. 1st retry after 1 min, 2nd after 5 mins, 3rd after 15 mins).
- **Exhaustion State**: Once the limit is reached, the retry loop is locked, and the incident is marked as `Failed - Escalated`.

---

## 6. Timeout Handling
Integration callouts during auto-heal runs must handle timeouts gracefully:
- **SLA Limits**: The default callout timeout is set to **10 seconds**.
- **Timeout Trap**: Standard callout exceptions (e.g., `System.CalloutException`) are caught by the try-catch block.
- **Fallback Action**: The transaction rolls back, and the incident is immediately flagged for human clearance in the Guardian Gate.

---

## 7. Duplicate Execution Prevention
To prevent race conditions where multiple processes attempt to auto-heal the same incident simultaneously:
- **Row Locking**: The engine locks the parent incident record at the start of execution:
   ```apex
   Sentinel_Incident__c lock = [SELECT Id, Execution_Status__c FROM Sentinel_Incident__c WHERE Id = :incidentId FOR UPDATE];
   ```
- **State Validation**: If the status is already `Executed` or `In Progress`, the execution immediately aborts to avoid duplicate API calls.

---

## 8. Failed Action Status Lifecycle
When an auto-heal action fails:
1. **Incident Status**: Transitions to `Failed` or `Action Failed`.
2. **Approval Status**: Reset to `Awaiting Review`.
3. **Execution Status**: Marked as `Failed`.
4. **Feedback loop**: The failed outcome is logged on the linked `Sentinel_Prediction__c` card to recalibrate future recommendation scores.

---

## 9. Audit Log Requirements
All failures and rollbacks must be logged to `Sentinel_Audit_Log__c`:
- **Record Entry**: Captures the failed action name, transaction ID, exception message, stack trace, and rollback confirmation.
- **Visibility**: Timeline components render the rollback events with a high-priority warning label.

---

## 10. Operator Notification Rules
When an Auto-Heal run fails:
- **Alert Channel**: Outbound Slack/Teams webhooks are fired immediately.
- **Payload Details**: Includes the parent incident ID, failed runbook key, error details, and a direct hyperlink to the record in Salesforce.
- **Urgency**: Tagged as `CRITICAL FAILURE - HUMAN INTERVENTION REQUIRED`.

---

## 11. Kill Switch Behavior
A global Custom Metadata setting `Auto_Heal_Active__c` functions as the master switch:
- **Deactivation**: If `Auto_Heal_Active__c = false`, the Auto-Heal engine halts all active workflows.
- **Behavior**: Staged actions are deleted, pending callouts are cancelled, and the system falls back to **Recommend Runbook** (advisory-only mode).

---

## 12. Success Criteria
1. **Zero Data Leaks**: Database states are completely clean following a rollback.
2. **Duplicate Block**: Verification that simultaneous calls result in exactly one execution, while secondary threads exit cleanly.
3. **Audit Completeness**: 100% of failed runs insert detailed logs detailing the error message and rollback completion.
4. **Immediate Alerting**: Webhook warnings are dispatched within 2 seconds of transactional failures.
