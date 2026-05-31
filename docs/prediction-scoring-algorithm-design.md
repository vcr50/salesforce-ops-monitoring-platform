# SentinelFlow Prediction Scoring Algorithm Design (Milestone 54C)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Proposal  
**Version**: 1.0  

---

## 1. Purpose

The purpose of this document is to design the mathematical scoring and statistical algorithms used by the SentinelFlow Prediction Engine to calculate **Anomaly Probability** and **Model Confidence** before an active system failure occurs.

---

## 2. Telemetry Input Signals

The scoring engine processes eight distinct input signals ($S_1$ to $S_8$), normalized to values between `0` (no anomaly) and `100` (critical anomaly):

1.  **Error Velocity ($S_1$)**: The rate of change of unhandled exceptions. Exponential increases (e.g., doubling errors over a 2-minute window) yield higher anomaly values.
2.  **Retry Spike ($S_2$)**: Density of retry counts on asynchronous queues. Approaching retry limits (e.g., job retrying 4/5 times) spikes this signal.
3.  **Recent Deployment Activity ($S_3$)**: Tracks Setup Audit Trail metadata changes. Value scales inversely with time elapsed: 100 at 0-15 minutes, 50 at 16-45 minutes, 0 after 60 minutes.
4.  **Repeated Flow Failures ($S_4$)**: Recurrence of Flow Fault events for the same Flow Developer Name within a rolling 10-minute window.
5.  **Integration Latency/Failure Rate ($S_5$)**: Normalized ratio of HTTP 5xx responses and connection timeouts.
6.  **Business Impact Score ($S_6$)**: Financial or database severity of records associated with active telemetry logs (mapped from standard risk metrics).
7.  **Historical Incident Recurrence ($S_7$)**: Statistical correlation with past incidents matching the same hour, day, or system update conditions.
8.  **Org Health Degradation ($S_8$)**: The velocity at which the system's overall health score index is declining.

---

## 3. Scoring Formula

The **Anomaly Probability Score ($P_{\text{anomaly}}$)** is calculated as a weighted linear combination of the normalized signal scores, bounded between 0% and 100%:

$$P_{\text{anomaly}} = \min\left(100, \sum_{i=1}^{8} (S_i \times W_i)\right)$$

Where:
*   $S_i \in [0, 100]$ represents the normalized anomaly score for signal $i$.
*   $W_i \in [0, 1]$ represents the assigned weight for signal $i$, such that $\sum W_i = 1.00$.

---

## 4. Weighting Model

Signal weights reflect historical correlation with actual outages and telemetry reliability:

| Symbol | Input Signal | Weight ($W_i$) | Rationale |
|---|---|---|---|
| $W_3$ | Recent Deployment Activity | **0.25** | System changes are the leading cause of operational anomalies. |
| $W_5$ | Integration Failure Rate | **0.20** | Direct indicator of external service failures. |
| $W_1$ | Error Velocity | **0.15** | Captures early exponential exception spikes. |
| $W_4$ | Repeated Flow Failures | **0.10** | Captures critical business process faults. |
| $W_2$ | Retry Spike | **0.10** | Highlights background job exhaustion. |
| $W_8$ | Org Health Degradation | **0.10** | Correlates overall system stability decay. |
| $W_6$ | Business Impact Score | **0.05** | Measures criticality of records. |
| $W_7$ | Historical Recurrence | **0.05** | Accounts for temporal patterns. |

---

## 5. Confidence Calculation

The **Model Confidence Score ($C$)** reflects the completeness of the telemetry data used to calculate the prediction:

$$C = C_{\text{base}} \times D_{\text{completeness}} \times T_{\text{recency}}$$

Where:
1.  **$C_{\text{base}}$**: Calculated as the ratio of warning-level signals to active signals:
    $$C_{\text{base}} = \frac{\text{Count of Signals with } S_i \ge 40}{\text{Total Active Signals}} \times 100$$
2.  **$D_{\text{completeness}}$**: The percentage of telemetry systems reporting logs within the window (e.g. 1.0 if all connections succeed, 0.5 if webhook listeners fail to report).
3.  **$T_{\text{recency}}$**: Time-decay factor that scales down if the latest anomaly signal occurred > 15 minutes ago.

---

## 6. Risk Thresholds

Calculated scores trigger progressive states in the SentinelFlow dashboard:

*   **Info Alerts ($P_{\text{anomaly}} < 40\%$)**: Anomaly logged silently to `Sentinel_Anomaly_Signal__c` for auditing. No operator alerts.
*   **Warning Alerts ($40\% \le P_{\text{anomaly}} < 70\%$)**: Card displayed on dashboard. LWC displays yellow alert, suggests runbook mitigation.
*   **Critical Alerts ($P_{\text{anomaly}} \ge 70\%$)**: Red card displayed on dashboard. Trigger priorities notification to Operators for review and manual execution.

---

## 7. Example Scenarios

### Scenario A: Metadata Deployment Triggering Integration Spikes
*   A deployment occurs 5 minutes ago ($S_3 = 100$).
*   Zoho CRM integration response times double, and timeouts increase ($S_5 = 80$).
*   System error velocity increases by 50% ($S_1 = 50$).
*   Other signals remain quiet ($S_i = 0$).

$$\text{Weighted Score} = (100 \times 0.25) + (80 \times 0.20) + (50 \times 0.15) = 25.0 + 16.0 + 7.5 = 48.5\%$$
*Result*: Anomaly Probability of **49%** (Warning state). The dashboard flags a "Potential Anomaly" and suggests running a runbook to verify Zoho connection limits.

### Scenario B: Imminent System Failure (Outage)
*   A metadata deployment occurs 10 minutes ago ($S_3 = 100$).
*   Downstream payment gateway goes offline, HTTP 500 error rate hits 100% ($S_5 = 100$).
*   Flow failures spike on Checkout Flow ($S_4 = 90$).
*   Apex exceptions double every minute ($S_1 = 100$).

$$\text{Weighted Score} = (100 \times 0.25) + (100 \times 0.20) + (90 \times 0.10) + (100 \times 0.15) = 25 + 20 + 9 + 15 = 69.0\%$$
*If Org Health degrades simultaneously ($S_8 = 50$)*:

$$\text{Total Score} = 69.0 + (50 \times 0.10) = 74.0\%$$
*Result*: Anomaly Probability of **74%** (Critical state). SentinelFlow triggers a high-priority operator alert to approve runbook mitigation.

---

## 8. False Positive / False Negative Feedback Loop

To refine predictions over time:
*   **False Positive (Operator Dismissal)**: If an operator dismisses a prediction as a false positive, the engine decreases the weights ($W_i$) associated with the contributing signals for that specific event source.
*   **False Negative (Unpredicted Failure)**: If a reactive incident is generated without a prior prediction alert, the engine retroactively queries telemetry signals within a 30-minute window before the incident to lower anomaly thresholds.

---

## 9. Explainability Output

The system writes explainability descriptions to `Explanation__c` using the following natural language mapping template:

> "Outage probability calculated at [Prediction_Score]% (Confidence: [Confidence_Score]%) because [Signal_Name_A] anomalous activity ([Metric_Value_A]) coincided with [Signal_Name_B] events ([Metric_Value_B]) within the last rolling window."

---

## 10. Human Governance Boundary (Core Safety Rule)

*   **Prediction Warning & Recommendation only**: The engine computes probabilities and selects runbooks.
*   **Operator Approval Required**: Proactive mitigations cannot execute autonomously. An operator must click Approve to execute the recommended runbook.
*   **Governor Safety**: Calculations will run asynchronously inside Queueable jobs or platform event triggers to stay well within Salesforce CPU limits (target < 50ms processing overhead).

---

## 11. Success Criteria

- [ ] Clean mathematical predictability (verifiable via Apex test suites).
- [ ] No recursive calculation overhead.
- [ ] Calculations complete within Governor bounds.
