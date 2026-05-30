# Auto-Heal GA Pilot Scope

## 1. Purpose
This document defines the operational scope, environment boundaries, test scenarios, success criteria, and governance gates for the **SentinelFlow Auto-Heal General Availability (GA) Pilot**. The pilot is designed to validate the safety, correctness, and GRC auditability of the Auto-Heal execution engine in a controlled sandbox environment before public release.

---

## 2. Pilot Environment
- **Target Sandbox**: Developer Sandbox `vjdev@asap.com`.
- **Target Configurations**:
  - Live mock telemetry metrics generated via the pilot simulation suite.
  - Active Slack/Teams webhook Named Credentials configured to route alerts to designated validation channels.
  - Email notification fallbacks linked to the pilot user email addresses.

---

## 3. Pilot Duration & Phases
The pilot will run for a continuous duration of **14 days**, divided into two operational phases:
- **Phase 1 (Days 1–7) — Advisory Calibration & Dry-Runs**:
  - The Auto-Heal engine runs in advisory mode.
  - Operators review generated recommendations and trigger execution in dry-run mode (using transaction rollbacks to test logic paths without persisting DML outcomes).
  - Telemetry logs are analyzed daily to tune thresholds.
- **Phase 2 (Days 8–14) — Guided Operator Clearance**:
  - Operators review and execute allowed actions under strict human-in-the-loop limits.
  - All database mutations and external integrations are committed to the sandbox database.
  - Failures and rollbacks are manually induced to verify alert dispatch loops.

---

## 4. Allowed Pilot Actions
Only registered, non-destructive recovery actions may be executed:
1. **`CREATE_CASE`**: Generates a standard Salesforce Case with priority mapped dynamically to risk score.
2. **`CREATE_TASK`**: Allocates an investigation task to a designated queue.
3. **`SEND_NOTIFICATION`**: Dispatches alert payloads asynchronously to Slack/Teams webhooks.
4. **`RETRY_SAFE_INTEGRATION`**: Initiates safe retries using configured `Runbook_Key__c` identifiers.
5. **`UPDATE_SENTINELFLOW_STATUS`**: Safely syncs internal statuses.
6. **`RECOMMEND_RUNBOOK`**: Recommends standard runbooks on the user interface.

*Note: Medium and High/Critical risk actions (Risk Score $\ge 40.0\%$) strictly require human approval via the Guardian Gate prior to execution.*

---

## 5. Blocked Pilot Actions
To protect database and metadata integrity, the following actions are programmatically blocked by policies:
- **Destructive Operations**: DELETE_RECORDS, MASS_UPDATE_BUSINESS_DATA.
- **Access Modifications**: CHANGE_PERMISSIONS, BYPASS_APPROVAL.
- **Configuration Changes**: MODIFY_METADATA, DISABLE_FLOW_TRIGGER.
- **Deployments**: DESTRUCTIVE_DEPLOYMENT.

Any attempt to trigger these actions results in transaction abort, savepoint rollback, log registration under `BLOCKED_ACTION`, and an immediate critical notification.

---

## 6. Test Scenarios
Four operational simulation profiles are scheduled during the pilot:
- **Scenario A — Downstream API Timeout**: ZooCRM integration callouts timeout consecutively. Auto-Heal traps CalloutException, rolls back database savepoints, transitions status to `'Failed'`, `'Approval Required'`, and `'Pending Approval'`, and logs a `TIMEOUT` audit event.
- **Scenario B — CPU Threshold Violation**: Post-deployment trigger CPU limits spike. Auto-Heal generates a Case and Task dynamically, mapping priorities to `High` for critical incident scores ($\ge 70.0\%$).
- **Scenario C — Low-Risk Webhook Throttle**: Transient Slack API rate throttling occurs. Telemetry suppresses predictions below 40% noise thresholds.
- **Scenario D — Retry Exhaustion**: Zoho CRM retry integration fails repeatedly. Auto-Heal attempts executions, increments counts, and locks further automated runs after 3 attempts, logging `RETRY_EXHAUSTED`.

---

## 7. Operator Participants
The pilot includes the following SRE and Administration team members:
- **Alex Rivera** (SRE Lead) — Primary operator for Phase 1 & 2 validation.
- **Priya Patel** (SRE) — Reviewer and secondary approver in the Guardian Gate.
- **Sarah Jenkins** (System Administrator) — Owner of Custom Metadata calibrations and webhook paths.
- **Tom Chen** (Director of Operations) — Business compliance and audit log validation lead.

---

## 8. Success Metrics
The pilot must achieve 100% compliance across the following quantitative KPIs:
- **Execution Precision ($\ge 98\%$)**: Percentage of executed actions that resolve anomalies without causing secondary database errors.
- **Zero Sharing Bypasses (100% pass)**: Confirm that all DML statements execute in user-mode context (`as user`) respecting FLS.
- **Rollback Integrity (100% pass)**: Confirm that failed transactions revert 100% of their database modifications, leaving zero orphan Cases or Tasks.
- **Alert Latency ($\le 2$ seconds)**: Time from execution failure to asynchronous Slack/Teams alert queueing.

---

## 9. Failure/Rollback Validation Protocol
When a failure occurs:
1. Confirm the transaction savepoint reverts all modifications.
2. Confirm the parent incident status transitions to `'Failed'`.
3. Confirm the parent incident is queued in the Guardian Gate as `'Approval Required'` and `'Pending Approval'`.
4. Confirm `Sentinel_Audit_Log__c` records contain exact exception stack traces.
5. Verify the audit log fallback retries with null lookup (`Incident__c = null`) if the incident is deleted.

---

## 10. Go / No-Go GA Promotion Criteria
The pilot will receive a **Go** decision for GA release only if all of the following gates are cleared:
- [ ] 14-day continuous validation run completed.
- [ ] At least 50 simulated execution runs processed.
- [ ] Zero database leaks or orphan records committed on rollback.
- [ ] Zero bypasses of the risk score approval gate.
- [ ] 100% of failures, timeouts, and duplicate executions logged to the audit trail.
- [ ] Operator satisfaction survey indicates ready and understood operational workflows.
