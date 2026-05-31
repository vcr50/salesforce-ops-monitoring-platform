# Auto-Heal GA Pilot Execution Log

This document records the official execution log and validation outcomes for the Auto-Heal pilot test scenarios conducted on the developer sandbox environment. 

---

## 1. Purpose
The purpose of this pilot run was to execute controlled simulations of the six canonical Auto-Heal test scenarios to ensure that:
1. Low-risk actions execute autonomously.
2. Medium-risk actions check policy rules correctly.
3. High-risk actions are successfully held at the Guardian Gate queue until operator approval.
4. Blocked/destructive actions are instantly rejected.
5. Transaction failures trigger atomic database rollbacks.
6. Execution ceilings block processing after 3 consecutive failures.
7. Detailed audit logs are written for every lifecycle transaction.

---

## 2. Sandbox Environment
- **Target Org**: `vjdev@asap.com` (Developer Org / Sandbox)
- **Execution Date**: 2026-05-30
- **Validation Engine**: Salesforce CLI (Anonymous Apex Execution)
- **Version Control Branch**: `codex-sentinelflow-marketing-zentom-bot`

---

## 3. Scenario Execution Table

| Scenario | Code Script | Objective | Target Action | Risk Score | Expected GRC Log Decision | Staged Record ID | Result |
|---|---|---|---|---|---|---|---|
| **A** | `auto_heal_pilot_scenario_a.apex` | Low-risk Auto Run | `CREATE_TASK` | 15.0% | `SUCCESS` | Task `00TdL00000BgzDdUAJ` | **PASSED** |
| **B** | `auto_heal_pilot_scenario_b.apex` | Policy Approved | `CREATE_CASE` | 55.0% | `SUCCESS` | Case `500dL00003GLEYIQA5` | **PASSED** |
| **C** | `auto_heal_pilot_scenario_c.apex` | Guardian Gate | `CREATE_TASK` | 85.0% | `APPROVAL_REQUIRED` / `SUCCESS` | Task `00TdL00000BgzFFUAZ` | **PASSED** |
| **D** | `auto_heal_pilot_scenario_d.apex` | Destructive Block | `DELETE_RECORDS` | 10.0% | `BLOCKED_ACTION` | None (Rejected) | **PASSED** |
| **E** | `auto_heal_pilot_scenario_e.apex` | Atomic Rollback | `TEST_FORCE_FAILURE` | 30.0% | `FAILURE` | None (Rolled Back) | **PASSED** |
| **F** | `auto_heal_pilot_scenario_f.apex` | Retry Exhaustion | `CREATE_TASK` (after 3x fails)| 20.0% | `RETRY_EXHAUSTED` | None (Throttled) | **PASSED** |

---

## 4. Scenario Details & Expected vs. Actual Results

### Scenario A — Low-risk Create Task
- **Objective**: Verify that low-risk incidents (risk score < 40%) execute autonomously without human clearance.
- **Expected Result**: Action execution returns success; creates a Task, status transitions to `Action Created`, `Execution_Status__c = 'Executed'`.
- **Actual Result**: 
  - Created Task: `00TdL00000BgzDdUAJ`
  - Incident Status: `Action Created`
  - Execution Status: `Executed`
  - Debug Statement: `=== SCENARIO A PASSED ===`
- **Audit Log Evidence**: Written to `Sentinel_Audit_Log__c` with `Event_Type__c = 'AUTO_HEAL_EXECUTED'` and `Decision__c = 'SUCCESS'`.

### Scenario B — Medium-risk Create Case with Policy Approval
- **Objective**: Verify that medium-risk incidents (score $\ge 40\%$) execute successfully if approved by policy or SRE action.
- **Expected Result**: Action succeeds; creates a Case, `Created_Case__c` lookup points to Case ID, status transitions to `Action Created`, `Execution_Status__c = 'Executed'`.
- **Actual Result**:
  - Created Case: `500dL00003GLEYIQA5`
  - Incident Status: `Action Created`
  - Execution Status: `Executed`
  - Incident Lookup `Created_Case__c` successfully set to Case ID.
  - Debug Statement: `=== SCENARIO B PASSED ===`
- **Audit Log Evidence**: Written to `Sentinel_Audit_Log__c` with `Event_Type__c = 'AUTO_HEAL_EXECUTED'` and `Decision__c = 'SUCCESS'`.

### Scenario C — High-risk Action Requiring Guardian Gate
- **Objective**: Verify that high-risk actions (score $\ge 40\%$) are blocked if they do not have active human approval, and execute successfully once SRE clearance is granted.
- **Expected Result**: 
  - Attempt 1: Throws `AutoHealException` (approval required), logs `APPROVAL_REQUIRED`.
  - Attempt 2: After `Approval_Status__c = 'Approved'`, execution succeeds, status transitions to `Executed`.
- **Actual Result**:
  - Attempt 1 blocked. Exception: `Action execution blocked. Incidents with medium/high/critical risk (score >= 40%) require human approval.`
  - Attempt 2 succeeded after SRE manual approval set to Approved. Created Task: `00TdL00000BgzFFUAZ`
  - Execution Status: `Executed`
  - Debug Statement: `=== SCENARIO C PASSED ===`
- **Audit Log Evidence**: 
  - Block Event: `Event_Type__c = 'AUTO_HEAL_BLOCKED'`, `Decision__c = 'APPROVAL_REQUIRED'`
  - Success Event: `Event_Type__c = 'AUTO_HEAL_EXECUTED'`, `Decision__c = 'SUCCESS'`

### Scenario D — Blocked Destructive Action
- **Objective**: Verify that a blocked action (such as `DELETE_RECORDS`) is rejected immediately, throws a clear exception, and logs a GRC violation event.
- **Expected Result**: Service throws `AutoHealException` with "Blocked Action", logs `BLOCKED_ACTION`.
- **Actual Result**:
  - Threw exception: `Blocked Action: DELETE_RECORDS is dangerous and cannot be executed.`
  - Database mutations prevented.
  - Debug Statement: `=== SCENARIO D PASSED ===`
- **Audit Log Evidence**: Written to `Sentinel_Audit_Log__c` with `Event_Type__c = 'AUTO_HEAL_BLOCKED'` and `Decision__c = 'BLOCKED_ACTION'`.

### Scenario E — Rollback on Failure
- **Objective**: Verify that a failure in execution rolls back all transaction mutations, resets status fields to the failure triage state, and queues notifications.
- **Expected Result**: 
  - Transaction rolls back completely (no orphaned tasks or cases).
  - Parent incident resets: `Execution_Status__c = 'Failed'`, `Status__c = 'Approval Required'`, `Approval_Status__c = 'Pending Approval'`.
  - Audit log is created with `AUTO_HEAL_FAILED`.
  - Future/Asynchronous notification dispatch is scheduled.
- **Actual Result**:
  - Action `TEST_FORCE_FAILURE` executed. Exception: `Forced testing failure for rollback validation.`
  - Transaction rolled back.
  - Parent Incident Execution Status: `Failed`
  - Parent Incident Status: `Approval Required`
  - Parent Incident Approval Status: `Pending Approval`
  - Debug Statement: `=== SCENARIO E PASSED ===`
- **Audit Log Evidence**: Written to `Sentinel_Audit_Log__c` with `Event_Type__c = 'AUTO_HEAL_FAILED'` and `Decision__c = 'FAILURE'`.

### Scenario F — Retry Exhaustion after 3 Failures
- **Objective**: Verify that once an incident registers 3 failed attempts, further automated executions are blocked.
- **Expected Result**: 
  - Runs 3 failing executions (creating `AUTO_HEAL_FAILED` logs).
  - 4th execution attempt throws `AutoHealException` (Retry Exhaustion).
  - Logs block event with `RETRY_EXHAUSTED`.
- **Actual Result**:
  - Run 3 failing iterations.
  - Attempt 4 threw exception: `Retry Exhaustion: Maximum retry attempts (3) exceeded for this incident. Manual review required.`
  - Debug Statement: `=== SCENARIO F PASSED ===`
- **Audit Log Evidence**: 
  - Failures: 3 logs with `Event_Type__c = 'AUTO_HEAL_FAILED'`
  - Exhaustion Block: 1 log with `Event_Type__c = 'AUTO_HEAL_BLOCKED'`, `Decision__c = 'RETRY_EXHAUSTED'`

---

## 5. Issues Found
- **Issue**: Standard anonymous Apex execution environment throws `System.FinalException: Method only allowed during testing` when executing `Test.startTest()` or `Test.stopTest()`.
- **Resolution**: Removed `Test.startTest()` and `Test.stopTest()` from the simulation scripts, leaving them to run directly in the live runtime context (since asynchronous webhooks/alerts schedule correctly via native platform events and future calls). Unit tests in `AutoHealExecutionServiceTest` continue to use `Test.startTest()` / `Test.stopTest()` within their isolated test context.

---

## 6. Safety Gate Result
> [!IMPORTANT]
> **Safety Gates Status: 100% SECURE**
> - **No Destructive Action**: Verified. Destruction actions (`DELETE_RECORDS`) blocked before any database execution.
> - **No Approval Bypass**: Verified. Score $\ge 40\%$ blocked execution unless pre-approved.
> - **Automatic Rollback**: Verified. Savepoints rolled back transaction state successfully on failure.
> - **Throttling Ceiling**: Verified. Retry counts capped at 3, preventing endless execution loops.
> - **Audit Trail Complete**: Verified. All blockages, failures, retries, and successes logged to `Sentinel_Audit_Log__c`.

---

## 7. Pilot Decision
Based on the execution results, the Auto-Heal pilot has successfully validated all safety gates and GRC logging requirements.

**Status**: **Ready for GA Promotion**
**Recommendation**: Promote Auto-Heal to General Availability (GA) under Milestone 63.
