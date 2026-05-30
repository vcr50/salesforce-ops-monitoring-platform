# Auto-Heal Audit & Compliance Evidence Design

## 1. Purpose
This document defines the auditing standards, event schemas, compliance views, and retention guidelines required to make SentinelFlow's Auto-Heal engine fully explainable, traceable, reversible, and ready for enterprise IT compliance audits. The core rule of this design is that **every automated action must be explainable, traceable, reversible where possible, and audit-ready**.

---

## 2. Audit Event Taxonomy
The Auto-Heal engine categorizes all operational events into a structured taxonomy:
- **`AUTO_HEAL_RECOMMENDED`**: The Prediction Engine has recommended a runbook mitigation.
- **`APPROVAL_REQUESTED`**: Staged action is frozen and human clearance is requested in the queue.
- **`APPROVAL_GRANTED` / `APPROVAL_REJECTED`**: Operator decisions on pending approvals.
- **`EXECUTION_STARTED`**: Auto-Heal engine starts DML/callout execution.
- **`EXECUTION_COMPLETED`**: Safe actions (e.g. Case/Task creation) completed successfully.
- **`EXECUTION_FAILED`**: Operational step failed, capturing the exception state.
- **`ROLLBACK_TRIGGERED` / `ROLLBACK_COMPLETED`**: Reverting database state due to failures.
- **`EMERGENCY_STOP_TRIGGERED`**: A run aborted due to the global kill switch activation.

---

## 3. Required Audit Fields
Every audit event must be persisted inside the `Sentinel_Audit_Log__c` object with the following fields populated:
- **`Event_Type__c`** (Picklist): Event category mapped from the taxonomy.
- **`Incident__c`** (Lookup): Parent `Sentinel_Incident__c` reference.
- **`Actor__c`** (Text/Lookup): User ID of the operator, or `System / Auto-Heal Engine`.
- **`Request_Payload__c`** (Long Text Area): Detailed execution inputs, runbook key, and status values.
- **`Response_Payload__c`** (Long Text Area): Execution outcomes, DML record IDs, or detailed exception stack traces.
- **`Created_By_System__c`** (Boolean): Indicates whether the event was generated automatically by the engine.
- **`Trace_Id__c`** (Text): A unique UUID mapping all events in a single execution flow.

---

## 4. Approval Audit Trail
To satisfy digital signature and GRC audits:
- **Record Information**: Log the exact timestamp of approval/rejection.
- **Operator Context**: Capture the approver's User ID, Profile, and IP address (if applicable).
- **Justification**: Rejections require a mandatory textual reason logged inside the `Reason__c` field on `Zentom_Policy_Decision__c`.

---

## 5. Execution Audit Trail
For every execution run:
- **Timestamp Tracking**: Log start (`Executed_At__c`) and end times to calculate Mean Time to Resolution (MTTR).
- **DML Target Summary**: Record the created record IDs (e.g., Salesforce `Case` ID or `Task` ID) to ensure direct lookup traceability from the audit timeline.

---

## 6. Rollback Audit Trail
If an execution fails and trigger rollbacks:
- **Savepoint Logs**: Log when a rollback is initiated and verify completion: `"Savepoint SP_UUID successfully rolled back"`.
- **Compensating Actions**: Audit trail logs if any outbound alerts are canceled or if generated cases are closed out automatically.

---

## 7. Failure Audit Trail
Failed executions must capture:
- **Exception Class**: System callout exceptions, DML exceptions, or limits exceptions.
- **Governor Limit States**: Remaining CPU time, Heap size, and DML statement counts at the moment of failure.
- **Troubleshooting Link**: A direct hyperlink to the diagnostic SRE runbook.

---

## 8. Operator Decision Evidence
Capture and store operator calibration choices:
- **Trust Adjustments**: Record updates to `Operator_Decision__c` (`Confirmed`, `Dismissed`, `Useful`, `False Positive`).
- **OTS Calibration**: Logs the rolling decay Operational Trust Score modification resulting from this run.

---

## 9. Compliance Reporting View
To provide transparency for IT auditors:
- **Audit Dashboard**: Custom Salesforce list views and reports matching GRC criteria.
- **Key Columns**: Incident Name, Risk Level, Action Executed, Approved By, Execution Status, Rollback Executed?, and Audit Link.
- **AppExchange Verification**: Reports will be bundled inside the managed package to enable plug-and-play compliance audits.

---

## 10. Data Retention Policy
To prevent storage bloat while satisfying compliance mandates:
- **Raw Telemetry / Signals**: Automatically purged after **30 days**.
- **Incident Records**: Retained for **180 days** on-org.
- **Audit Logs (`Sentinel_Audit_Log__c`)**: Retained for **365 days** on-org.
- **Archiving**: Systems must support exporting logs to external secure vaults (e.g. AWS S3 or Salesforce Big Objects) for long-term historical retention.

---

## 11. Security / FLS Rules
Audit logs must be tamper-proof:
- **Read-Only Lock**: `Sentinel_Audit_Log__c` records can be created by the system, but editing or deleting existing logs is strictly blocked (`WITH USER_MODE` and validation rules).
- **FLS Enforcement**: All compliance views and controllers must strip inaccessible fields using `Security.stripInaccessible()`.

---

## 12. Success Criteria
1. **Audit Traceability**: 100% of auto-heal executions can be traced back to a specific prediction, scoring calculation, and human approval.
2. **Tamper-Proof Audit**: Verification that operators cannot edit or delete audit trail logs.
3. **No Orphan Logs**: 100% of transactional rollbacks successfully write a corresponding rollback log.
4. **Retention Engine Compliance**: Successful execution of automated delete or archive routines after the retention period.
