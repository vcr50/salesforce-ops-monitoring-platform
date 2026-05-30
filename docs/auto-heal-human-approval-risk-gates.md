# Human Approval Rules & Risk Gate Design

## 1. Purpose
This document defines the human-in-the-loop approval workflows, risk gate score ranges, escalation policies, and audit conditions governing SentinelFlow's Auto-Heal engine for General Availability (GA). The design guarantees that execution risk controls operational autonomy, ensuring high-risk actions are approved by authorized engineers prior to execution.

---

## 2. Risk Level Definitions
Risk levels are determined by the incident or prediction anomaly score ($P_{\text{anomaly}}$) calculated by the scoring engines:
- **Low Risk (`0% - 39%`)**: Minor deviations, transient telemetry fluctuations, or self-healing integration alerts.
- **Medium Risk (`40% - 69%`)**: System degradation, high CPU overhead, or repeated retry loop exhaustions.
- **High Risk (`70% - 89%`)**: Critical resource exhaustion, service failures on sandboxes, or deployment regression patterns.
- **Critical Risk (`90% - 100%`)**: Direct production outages, core workflow failures, security posture threats, or imminent system blockages.

---

## 3. Low-Risk Action Rules
For incidents or predictions with a risk score $< 40\%$:
- **Autonomy**: High. The Auto-Heal engine is allowed to execute safe, non-destructive actions autonomously if policy dictates.
- **Allowed Actions**:
  - `Recommend Runbook` (UI advisor).
  - `Send Notification` (Slack, Teams, Email).
  - `Create Task` (Assign follow-up to support queue).
- **Execution flow**: Triggers immediately on incident creation; logs to the timeline.

---

## 4. Medium-Risk Action Rules
For incidents or predictions with a risk score between $40\%$ and $69\%$:
- **Autonomy**: Bounded.
- **Approval Gate**: Requires policy-level validation or operator sign-off.
- **Allowed Actions**:
  - `Create Case` (standard support ticket).
  - `Update SentinelFlow Status` (marking incident under review).
  - `Retry Safe Integration` (replaying failed calls).
- **Execution flow**: Auto-Heal drafts the action and places it in the Action Center queue. SRE operators must toggle "Approve Action" in the console or have custom metadata policies that explicitly authorize the specific integration retry.

---

## 5. High-Risk Action Rules
For incidents or predictions with a risk score between $70\%$ and $89\%$:
- **Autonomy**: None.
- **Approval Gate**: Mandatory human approval via the **Guardian Gate** queue.
- **Allowed Actions**:
  - Safe operations (e.g. creating cases, sending alerts, retrying integrations) are staged but **frozen** from database commit.
- **Execution flow**: The engine inserts a `Sentinel_Incident__c` with status `Approval Required` and `Approval_Status__c = 'Pending Approval'`. No auto-heal execution begins until an authorized operator clicks "Approve Workflow".

---

## 6. Critical-Risk Action Rules
For incidents or predictions with a risk score $\ge 90\%$:
- **Autonomy**: Zero.
- **Approval Gate**: Double-gated. Mandatory human approval via the **Guardian Gate** with automated escalation routing.
- **Execution flow**: The engine immediately halts any autonomous action, logs the incident, triggers alerts to Slack/Teams with a critical tag, and places the approval record in the queue. Only a designated Administrator or SRE Lead can approve.

---

## 7. Guardian Gate Approval Mapping
The approval record mappings enforce strict relation locks:
- **Incident State**: Created incident has `Incident_Type__c = 'Predicted Anomaly'` or `'System Incident'`.
- **Relationship Lookup**: Linked bidirectionally via `Source_Prediction__c` (on Incident) and `Incident__c` (on Prediction).
- **Governance Status**:
  - `Approval Required` status freezes any automation block.
  - `Approved` status moves the action to `Ready for Execution`.
  - `Rejected` status terminates the run and releases the prediction cards.

---

## 8. Policy Decision Mapping
When an operator approves or rejects a runbook:
- **Trust Calibration**: The choice updates `Operator_Decision__c` to `Confirmed` or `Dismissed` (False Positive).
- **Feedback Loop**: This decision is captured, altering the historical trust score decay of the active prediction algorithm.

---

## 9. Approval Timeout & Escalation Paths
To prevent critical incidents from stalling indefinitely in the clearance queue:
- **SLA Expiration**: If a `High` or `Critical` incident remains in `Pending Approval` for more than **4 hours** (governed by the custom metadata setting `Escalation_Threshold_Hours`):
  - **Escalation Trigger**: The incident is flagged as `Escalation Needed`.
  - **Re-routing**: Outbound SRE alert channels trigger pager duty notifications.
  - **Status Change**: The LWC table highlights the row in warning crimson.

---

## 10. Audit Requirements
All gate transitions must write to `Sentinel_Audit_Log__c`:
- **State Changes**: Logged when an incident moves to `Pending Approval`, `Approved`, `Rejected`, or `Escalated`.
- **Actor Identification**: Logs the User ID of the operator confirming the decision.
- **Reason Capture**: Rejections must record the operator's qualitative cancellation reason.

---

## 11. Success Criteria
1. **Zero Approval Bypass**: No DML or integration retries trigger without matching the risk-based approval workflow.
2. **Deterministic Locking**: Double-click or duplicate approval requests are blocked by database locks (`FOR UPDATE`).
3. **Escalation Auditing**: The system successfully flags and alerts on SLA expirations after the 4-hour threshold.
4. **Clean Rollbacks**: Any rejection or timeout properly rolls back the transactional database state.
