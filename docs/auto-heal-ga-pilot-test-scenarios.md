# Auto-Heal GA Pilot Test Scenarios

## 1. Purpose
This document provides the operational guide and verification procedures for executing the six canonical Auto-Heal pilot test scenarios. These scenarios validate the correct behavior of allowed actions, blocked action policies, risk gates, savepoint rollbacks, retry limits, and GRC audit logs.

---

## 2. Pilot Environment
- **Target Org**: `vjdev@asap.com` (Developer Sandbox).
- **Tooling**: Salesforce CLI or Anonymous Apex runner.
- **Paths**: Script files are located in the repository under [`scripts/apex/`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/).

---

## 3. Scenario A — Low-risk Create Task
- **Objective**: Verify that a low-risk incident (risk score < 40%) executes autonomously without human-in-the-loop clearance.
- **Script**: [`auto_heal_pilot_scenario_a.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_a.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_a.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The script succeeds.
  - A Task is created and linked to the incident.
  - `Execution_Status__c` transitions to `'Executed'`, and `Status__c` transitions to `'Action Created'`.
  - A `SUCCESS` audit log is written to `Sentinel_Audit_Log__c`.

---

## 4. Scenario B — Medium-risk Create Case with Policy Approval
- **Objective**: Verify that a medium-risk incident (score $\ge 40\%$) executes successfully if approved by policy or SRE action.
- **Script**: [`auto_heal_pilot_scenario_b.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_b.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_b.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The script succeeds.
  - A Case is created.
  - `Execution_Status__c` transitions to `'Executed'`.
  - The `Created_Case__c` field on the incident lookup points to the Case ID.

---

## 5. Scenario C — High-risk Action Requiring Guardian Gate
- **Objective**: Verify that high-risk actions (score $\ge 40\%$) are blocked if they do not have active human approval, and execute successfully once SRE clearance is granted.
- **Script**: [`auto_heal_pilot_scenario_c.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_c.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_c.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The first attempt fails with an `AutoHealException` stating that approval is required.
  - An `APPROVAL_REQUIRED` block log is written.
  - The second attempt (after setting `Approval_Status__c = 'Approved'`) succeeds.

---

## 6. Scenario D — Blocked Destructive Action
- **Objective**: Verify that a blocked action (such as `DELETE_RECORDS`) is rejected immediately, throws a clear exception, and logs a GRC violation event.
- **Script**: [`auto_heal_pilot_scenario_d.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_d.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_d.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The service throws `GovernanceException: Blocked Action: DELETE_RECORDS is dangerous`.
  - An audit log with `Event_Type__c` = `'AUTO_HEAL_BLOCKED'` and `Decision__c` = `'BLOCKED_ACTION'` is written.
  - No database records are deleted.

---

## 7. Scenario E — Rollback on Failure
- **Objective**: Verify that a failure in execution rolls back all transaction mutations, resets status fields to the failure triage state, and queues notifications.
- **Script**: [`auto_heal_pilot_scenario_e.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_e.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_e.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The script runs `TEST_FORCE_FAILURE`.
  - The database rolls back, leaving no orphaned Task or Case.
  - Parent incident resets: `Execution_Status__c = 'Failed'`, `Status__c = 'Approval Required'`, `Approval_Status__c = 'Pending Approval'`.
  - An audit log with `Event_Type__c` = `'AUTO_HEAL_FAILED'` is written.
  - Asynchronous webhook notifications are queued for operators.

---

## 8. Scenario F — Retry Exhaustion after 3 Failures
- **Objective**: Verify that once an incident registers 3 failed attempts, further automated executions are blocked.
- **Script**: [`auto_heal_pilot_scenario_f.apex`](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/auto_heal_pilot_scenario_f.apex)
- **Execution Command**:
  ```powershell
  sf apex run --file scripts/apex/auto_heal_pilot_scenario_f.apex -o vjdev@asap.com
  ```
- **Expected Results**:
  - The script simulates 3 consecutive failures.
  - The 4th execution attempt throws an `AutoHealException` stating retry exhaustion limits.
  - A block audit log is created with `Decision__c` = `'RETRY_EXHAUSTED'`.

---

## 9. Expected Audit Logs Summary
During test runs, verify that `Sentinel_Audit_Log__c` records match the expected states:
- **Scenario A**: `Event_Type__c = 'AUTO_HEAL_EXECUTED'`, `Decision__c = 'SUCCESS'`.
- **Scenario B**: `Event_Type__c = 'AUTO_HEAL_EXECUTED'`, `Decision__c = 'SUCCESS'`.
- **Scenario C**: `Event_Type__c = 'AUTO_HEAL_BLOCKED'`, `Decision__c = 'APPROVAL_REQUIRED'` followed by `SUCCESS`.
- **Scenario D**: `Event_Type__c = 'AUTO_HEAL_BLOCKED'`, `Decision__c = 'BLOCKED_ACTION'`.
- **Scenario E**: `Event_Type__c = 'AUTO_HEAL_FAILED'`, `Decision__c = 'FAILURE'` (or `ROLLBACK_EXECUTED`).
- **Scenario F**: `Event_Type__c = 'AUTO_HEAL_BLOCKED'`, `Decision__c = 'RETRY_EXHAUSTED'`.

---

## 10. Pass / Fail Verification Checklist
Run all six scenario scripts in sequence. Use the following validation table:

| Scenario | Script | Target Exception / Behavior | Passed? |
|---|---|---|---|
| A | `auto_heal_pilot_scenario_a.apex` | Executes CREATE_TASK autonomously, status `Executed` | [ ] |
| B | `auto_heal_pilot_scenario_b.apex` | Executes CREATE_CASE under medium risk approved, status `Executed` | [ ] |
| C | `auto_heal_pilot_scenario_c.apex` | First attempt blocked, second approved attempt executes successfully | [ ] |
| D | `auto_heal_pilot_scenario_d.apex` | DELETE_RECORDS blocked with `Blocked Action` exception | [ ] |
| E | `auto_heal_pilot_scenario_e.apex` | Transaction rolled back, parent status reset, webhook queued | [ ] |
| F | `auto_heal_pilot_scenario_f.apex` | 4th execution blocked with `Retry Exhaustion` exception | [ ] |
