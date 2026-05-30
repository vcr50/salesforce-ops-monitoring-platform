# SentinelFlow Prediction Engine — Result Review & Tuning Plan

This document establishes the operational tuning plan for SentinelFlow’s proactive anomaly prediction engine. Based on the data gathered during the Milestone 57 sandbox pilot runs, we analyze coefficient weights, signal thresholds, and explanation patterns to align prediction scores with expected operational realities.

---

## 1. Purpose
The purpose of the Tuning Plan is to adjust the prediction engine's linear scoring model to better reflect the severity and correlation of outage telemetry signals. Specifically, this plan aims to:
- Calibrate weights so that deployment-correlated incidents (e.g., Scenario B) are scored higher in the Critical range.
- Validate that low-risk transient anomalies (e.g., Scenario D) remain suppressed below the active dashboard threshold.
- Improve natural language explanation strings for clarity, providing operators with actionable insights.
- Define a structured path for re-testing without introducing autonomous predictive remediation.

---

## 2. Pilot Result Summary
During the dry-run execution log phase, four scenarios were processed through the prediction scoring pipeline:
1. **Scenario A (Zoho CRM Timeout Spike)**: Simulated 100% callout failures and 80.0 error velocity. Calculated score: **77%** (Critical).
2. **Scenario B (HubSpot Sync Deployment Correlation)**: Simulated a metadata deploy followed by CPU time limit exceptions and 80.0% callout failures. Calculated score: **79%** (Critical).
3. **Scenario C (Order Processing Flow Exhaustion)**: Simulated 8 Flow failures and 75.0 error velocity. Calculated score: **55%** (Warning).
4. **Scenario D (Slack Webhook Rate-Limit Noise)**: Simulated 1 transient retry and 8.0% error rate. Calculated score: **32%** (Suppressed; no prediction card generated).

---

## 3. Expected vs. Actual Score Comparison

| Scenario | Target / Expected Score | Actual Pilot Score | Current Variance | Assessment |
| :--- | :--- | :--- | :--- | :--- |
| **Scenario A** (API Timeout) | ~78% | **77%** | -1% | **Strong Alignment**: Accurately flags integration failures. |
| **Scenario B** (Deployment Corr.) | ~85% | **79%** | -6% | **Slightly Low**: The correlation between recent metadata changes and high CPU exhaustion should yield a higher score. |
| **Scenario C** (Flow Exhaustion) | ~55% | **55%** | 0% | **Perfect Alignment**: Warning threshold is correctly met. |
| **Scenario D** (Webhook Noise) | < 40% | **32%** | N/A | **Safe**: Safely below the 40% active card generation threshold. |

---

## 4. Signal Weight Tuning Recommendations
To bridge the -6% variance in **Scenario B** and bring it within the target **82% – 88%** range, we recommend adjusting the evaluation coefficients. 

### Recommended Adjustments:
1. **Increase Deployment Weight ($W_3$)**:
   - *Current Weight*: 0.40 (in Scenario B override)
   - *Proposed Weight*: **0.45**
   - *Rationale*: A metadata change followed by immediate error signals is the highest indicator of regression. Increasing this weight ensures deployment-related anomalies are highlighted.
2. **Increase CPU Limit / Apex Exception contribution**:
   - *Current Weight*: 0.20 (in Scenario B override)
   - *Proposed Weight*: **0.25**
   - *Rationale*: Apex Exceptions represent critical runtime breaks (e.g., LimitExceptions) which have higher impact than standard retry signals.
3. **Rebalance Secondary Weights**:
   - To keep total normalized weight at **1.0 (100%)**, reduce less critical weights such as Integration Failure or business impact slightly.

```
Proposed Scenario B Tuning Config:
----------------------------------------
SystemSettings.setOverride('Prediction_Weight_Deployment', 0.45);  // +0.05
SystemSettings.setOverride('Prediction_Weight_Error',      0.25);  // +0.05
SystemSettings.setOverride('Prediction_Weight_Integration',0.20);  // -0.05
SystemSettings.setOverride('Prediction_Weight_Retry',      0.03);  // -0.02
SystemSettings.setOverride('Prediction_Weight_Flow',       0.03);  // -0.02
SystemSettings.setOverride('Prediction_Weight_Business',   0.02);  // -0.005
SystemSettings.setOverride('Prediction_Weight_Health',     0.02);  // -0.005
```

---

## 5. Threshold Tuning Recommendations
- **Warning Threshold (40%)**: Retained. A score of 40% provides adequate lead time for warning cards without causing alert fatigue.
- **Critical Threshold (70%)**: Retained. Scores $\ge 70\%$ represent high-confidence threats where active integration or system downtime is highly probable.
- **Noise Ceiling (40%)**: Retained. Any score below 40% is suppressed, ensuring that transient issues (like rate limiting) do not clutter the dashboard.

---

## 6. Noise Suppression Review
*Scenario D* generated a score of **32%**, which successfully filtered it from rendering. However, to ensure that multiple transient webhooks do not accumulate and push the score above 40%, we propose:
- Implementing a **signal cooldown window** where minor retries are throttled from recalculations for 15 minutes after a resolved warning.
- Suppressing `Slack_Webhook` predictions entirely unless failure rates exceed 15.0%.

---

## 7. Explanation Quality Improvements
The current explanation engine outputs a single unified sentence joining reasons with `and`.
- *Example*: `...because integration failures spiked to 80.0% and system error velocity increased significantly...`
- *Recommended Improvement*: Enhance `SentinelPredictionExplanationService.cls` to order reasons by their calculated contribution score. The primary driver of the anomaly should always appear first.
- *Visual Structure*: Support bulleted points in the detail panel if the LWC supports multi-line explanations.

---

## 8. Operator Trust Impact
Tuning these weights has a direct impact on the **Operational Trust Score (OTS)**. By raising the score of Scenario B:
- **Recall** is improved because deployment-related incident cards are prominently classified as Critical, matching operator expectations.
- **Precision** is preserved because the threshold rules keep noise (Scenario D) suppressed.
- **Governance Constraint**: Autonomy remains locked. Tuning only affects UI warnings and runbook recommendations; the system will not perform autonomous remediation without explicit human approval.

---

## 9. Retest Plan
Upon user approval of this tuning plan:
1. Update `scripts/apex/simulate_pilot_scenario_b.apex` with the new tuned weights.
2. Execute Scenario B in **Dry-Run Mode** to verify the score lands in the **82% – 88%** range.
3. Once validated, run all 4 scenarios in dry-run mode to verify regression-safety.

---

## 10. Success Criteria
The tuning phase will be considered successful when:
- **Scenario B score** is calculated between **82.00% and 88.00%** inclusive.
- **Scenario A and C scores** remain stable and aligned within +/- 2% of their targets.
- **Scenario D score** remains under the **40%** threshold.
- The unit tests pass with 100% success rate.
