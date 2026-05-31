# SentinelFlow Prediction Engine Architecture Plan (Milestone 54A)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Proposal  
**Version**: 1.0  

---

## 1. Purpose

The purpose of this architecture plan is to design the **SentinelFlow Prediction Engine**, transitioning the product from reactive healing to **predictive operations intelligence**. By identifying patterns and correlating disparate signals (such as log velocities, deployment events, and error frequencies), the system will anticipate operational anomalies and recommend proactive mitigations before systems experience critical failures or SLAs are breached.

---

## 2. Current Reactive Auto-Heal Model

SentinelFlow's current auto-healing model is strictly reactive:
1.  An anomaly occurs (e.g., an Apex Exception is thrown, an integration log fails, or a Salesforce Flow faults).
2.  The incident trigger captures the event and creates a `Sentinel_Incident__c` record.
3.  The rules engine routes the incident, calculates risk scores, and selects a runbook.
4.  If approved (manually or automatically under threshold bounds), the runbook executes to mitigate the *active* failure.

*Limitation*: While MTTR is minimized, the system still incurs a brief window of disruption, and customer cases or transaction failures may still occur before self-healing concludes.

---

## 3. Why the Prediction Engine is Needed

Reactive operations are no longer sufficient at enterprise scale. The Prediction Engine is designed to achieve:
*   **Zero-Downtime Operations**: Triggering preemptive actions (e.g., flushing cache partitions, warning upstream integration partners, or throttling request queues) *before* a failure impacts users.
*   **Change-Failure Correlation**: Pinpointing whether recent metadata deployments or package installations are directly contributing to rising error counts.
*   **Operational Foresight**: Surfacing impending issues (such as API rate-limit exhaustion or downstream service degradation) via the SentinelFlow dashboard.

---

## 4. Candidate Input Signals

The Prediction Engine will continuously ingest and analyze the following telemetry signals:

| Signal | Source | Purpose | Weight |
|---|---|---|---|
| **Flow Failures** | Flow Interview Logs | Tracks frequency and types of faults in business logic. | High |
| **Integration Logs** | `Integration_Log__c` | Measures HTTP failure rates, status codes (4xx/5xx), and timeout counts. | High |
| **Apex Exceptions** | Apex System Logs | Captures unhandled runtime errors and stack trace patterns. | High |
| **Error Frequency** | Telemetry Events | Measures error spikes over rolling 5-minute intervals. | Medium |
| **Retry Count** | Queue/Job Telemetry | Identifies background jobs hitting retry exhaustion limits. | Medium |
| **Historical Patterns** | Sentinel Incidents | Analyzes recurring times of day or seasonal event loads. | Low |
| **Business Impact Score** | Risk Matrix | Evaluates the monetary or data value of impacted records. | Medium |
| **Tenant/Org Health** | Health Telemetry | Tracks overall health score degradation trends. | Medium |
| **Recent Deployments** | `SetupAuditTrail` | Tracks recent metadata changes, package installs, and configuration updates. | High |

---

## 5. Prediction Scoring Model

The Prediction Engine calculates an **Anomaly Probability Score** (0 to 100) using a weighted linear combination of active signal anomalies:

$$P_{\text{anomaly}} = \sum (S_i \times W_i)$$

Where:
*   $S_i$ is the normalized signal anomaly score (0 to 100).
*   $W_i$ is the assigned weight of the signal (normalized to sum to 1.0).

### Key Algorithms (Pilot Phase):
1.  **Velocity Tracking**: Tracks whether error counts on a specific integration endpoint are growing exponentially (e.g., doubling every 2 minutes).
2.  **Temporal Correlation**: Correlates Setup Audit Trail deployment timestamps with immediate spikes in runtime exceptions.

---

## 6. Risk Thresholds & Action Mapping

Based on the calculated probability score, the dashboard will categorize anomalies and recommend mitigations:

| Probability Score | Risk Category | Dashboard Indicator | Recommended Action |
|---|---|---|---|
| **< 40** | Low Anomaly | 🟢 Normal / Info | Log signal silently; no operator action required. |
| **40 - 70** | Potential Anomaly | 🟡 Warning | Highlight on Live Traffic Board; suggest proactive runbook. |
| **> 70** | Imminent Failure | 🔴 Critical Anomaly | Move to Active Recommendation Queue; prompt Operator for immediate clearance. |

---

## 7. Human Approval Boundary (Safety First)

To ensure enterprise-grade safety:
*   **No Autonomous Prediction Execution**: The Prediction Engine **will not** autonomously execute runbooks or modify system data without validation.
*   **Recommendation-Only**: The engine's role is strictly advisory. It will generate recommendation cards on the dashboard.
*   **Policy & Gate Controls**: Proactive runbooks will still require human operator approval (or strict policy evaluation matching existing manual controls) before execution.

---

## 8. Data Storage Model (Proposed)

We will introduce a new schema to model predictive signals without overloading the standard incident table:

### A. Anomaly Signal Record (`Sentinel_Anomaly_Signal__c`)
*   `Signal_Type__c` (Picklist: Integration, Apex, Deployment, Flow)
*   `Event_Source__c` (Text: Endpoint URL, Class Name, Flow Developer Name)
*   `Error_Rate_Delta__c` (Decimal: Percentage spike)
*   `Timestamp__c` (DateTime)

### B. Predictive Recommendation (`Sentinel_Prediction__c`)
*   `Anomaly_Score__c` (Percent)
*   `Summary__c` (Text: AI-generated anomaly explanation)
*   `Correlation_Details__c` (Long TextArea: Detailed signal mapping)
*   `Recommended_Runbook__c` (Text: Key of runbook to resolve the issue)
*   `Status__c` (Picklist: Open, Dismissed, Escalated to Incident)

---

## 9. Explainability Requirements

Every recommendation must be fully explainable. Operators must see *why* the prediction was generated:
*   *Bad*: "We predict a Zoho CRM integration failure (Score: 85)."
*   *Good*: "We predict Zoho CRM integration failure (Score: 85) because a Metadata Deployment occurred at 10:15 PM and Zoho timeout counts increased by 400% in the last 5 minutes."

---

## 10. Security & Privacy Rules

*   **Zero Sensitive Payloads**: Signal records must never capture PII, tokens, or credential keys.
*   **FLS Compliance**: All new custom objects will enforce strict Field-Level Security matching `SentinelFlow_Admin` and `SentinelFlow_Operator` permission sets.
*   **System Integrity**: The Prediction Engine queries setup audit trails using system-level methods but will only surface metadata changes (no source code details).

---

## 11. Pilot Scope

The initial pilot of the prediction engine will focus exclusively on:
1.  **Downstream Integration Logs**: Monitoring Zoho, HubSpot, and Slack webhook HTTP status codes.
2.  **Deployment Monitoring**: Tracking if standard deployment activities correlate with integration failures.
3.  **Passive Recommendations**: Surface recommendations on a read-only widget on the dashboard for Operator review.

---

## 12. Success Criteria

*   **Precision**: $\ge 85\%$ of flagged "Imminent Failures" correlate with actual system degradation or errors within 30 minutes if not mitigated.
*   **Zero Interference**: The prediction engine must run in separate execution threads (asynchronous or queued) to ensure zero impact on reactive auto-healing flows.
*   **Audit Logging**: Every dismissal or approval of a prediction card must be written to `Sentinel_Audit_Log__c` for governance reporting.
