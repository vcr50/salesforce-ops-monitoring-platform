# SentinelFlow Prediction Sample Signal Scenarios (Milestone 56B)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Approved  
**Version**: 1.0  
**Target Environment**: `vjdev@asap.com`  

---

## 1. Purpose

Before the Prediction Engine can earn operator trust, the scoring model must be validated against realistic, reproducible telemetry patterns. This document defines four canonical signal scenarios — each targeting a distinct risk tier — that exercise the full prediction pipeline from raw signal ingestion through scoring, card rendering, and operator interaction.

These scenarios serve three critical functions:

1. **Scoring Calibration**: Verify that the weighted linear scoring model (`SentinelPredictionScoringService`) produces anomaly probability scores within the expected range for each risk category.
2. **UI State Verification**: Confirm that the glassmorphic prediction cards in `zentomDashboard` render the correct visual state (Critical / Warning / Info / Normal) based on calculated scores.
3. **Operator Action Validation**: Ensure that the human-in-the-loop governance flow (Approve → Create Incident / Dismiss → Suppress Card) behaves correctly across all risk tiers.

> [!IMPORTANT]
> **No autonomous execution occurs in any scenario.** Every prediction recommendation is advisory only. The operator must explicitly approve or dismiss each card. This constraint is absolute during the trust validation phase.

---

## 2. Scenario Data Setup

All scenarios will be executed using Anonymous Apex scripts within **isolated, rolled-back test transactions** to avoid polluting production data. Each script follows a standardized setup pattern:

### Setup Template

```apex
// =============================================
// Prediction Scenario Setup Template
// =============================================
// 1. Create Sentinel_Anomaly_Signal__c records
//    representing the raw telemetry inputs.
// 2. Invoke SentinelPredictionEngine.evaluate()
//    to trigger scoring and prediction creation.
// 3. Query Sentinel_Prediction__c to verify
//    the calculated score and recommendation.
// 4. Roll back all DML at script conclusion.
// =============================================

Savepoint sp = Database.setSavepoint();

try {
    // --- Signal Injection ---
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();

    // ... scenario-specific signal records inserted here ...

    insert signals;

    // --- Engine Evaluation ---
    SentinelPredictionEngine.evaluate();

    // --- Result Verification ---
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Anomaly_Score__c, Risk_Level__c,
               Summary__c, Recommended_Runbook__c, Status__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY
        ORDER BY Anomaly_Score__c DESC
    ];

    for (Sentinel_Prediction__c p : predictions) {
        System.debug('Score: ' + p.Anomaly_Score__c +
                     ' | Risk: ' + p.Risk_Level__c +
                     ' | Summary: ' + p.Summary__c);
    }
} finally {
    Database.rollback(sp);
}
```

### Shared Configuration Constants

| Parameter | Source | Default Value |
|---|---|---|
| Scoring Window | `System_Setting__mdt.Prediction_Scoring_Window_Minutes` | `5` minutes |
| Critical Threshold | `System_Setting__mdt.Prediction_Critical_Threshold` | `70` |
| Warning Threshold | `System_Setting__mdt.Prediction_Warning_Threshold` | `40` |
| Confidence Decay Half-Life | `System_Setting__mdt.Prediction_Decay_HalfLife_Minutes` | `15` minutes |
| Weight: Integration Failures | Scoring Matrix $W_1$ | `0.20` |
| Weight: Apex Exceptions | Scoring Matrix $W_2$ | `0.20` |
| Weight: Deployment Correlation | Scoring Matrix $W_3$ | `0.18` |
| Weight: Flow Failures | Scoring Matrix $W_4$ | `0.15` |
| Weight: Error Frequency | Scoring Matrix $W_5$ | `0.10` |
| Weight: Retry Exhaustion | Scoring Matrix $W_6$ | `0.07` |
| Weight: Business Impact | Scoring Matrix $W_7$ | `0.05` |
| Weight: Tenant Health | Scoring Matrix $W_8$ | `0.05` |

---

## 3. Scenario A — API Timeout Spike (High Risk / ~78%)

### Narrative
A downstream integration endpoint (`Zoho_CRM`) begins returning HTTP 504 Gateway Timeout responses at an accelerating rate. Within a 3-minute window, 15 consecutive failures are logged. The integration log failure delta spikes to **+400%** compared to the rolling hourly baseline. No recent deployments or metadata changes have occurred.

### Signal Injection

```apex
// Scenario A: API Timeout Spike
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();

for (Integer i = 0; i < 15; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Integration',
        Event_Source__c = 'Zoho_CRM',
        Error_Rate_Delta__c = 400.0,
        Signal_Value__c = 504,
        Timestamp__c = DateTime.now().addMinutes(-3 + i)
    ));
}

// Supporting context: elevated retry exhaustion
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Retry',
    Event_Source__c = 'Zoho_CRM_Queueable',
    Error_Rate_Delta__c = 250.0,
    Signal_Value__c = 5,
    Timestamp__c = DateTime.now().addMinutes(-1)
));
```

### Score Calculation Breakdown

| Signal Component | Normalized $S_i$ | Weight $W_i$ | Contribution |
|---|---|---|---|
| Integration Failures (504 × 15, +400% delta) | 95 | 0.20 | 19.0 |
| Apex Exceptions (none observed) | 0 | 0.20 | 0.0 |
| Deployment Correlation (none) | 0 | 0.18 | 0.0 |
| Flow Failures (none) | 0 | 0.15 | 0.0 |
| Error Frequency (15 errors / 3 min) | 85 | 0.10 | 8.5 |
| Retry Exhaustion (+250% delta) | 80 | 0.07 | 5.6 |
| Business Impact (Zoho CRM = high value) | 75 | 0.05 | 3.75 |
| Tenant Health (degraded) | 65 | 0.05 | 3.25 |
| **Total $P_{\text{anomaly}}$** | | | **~78** |

### Expected Results
- **Anomaly Score**: 75–82 (target: ~78)
- **Risk Level**: `Critical`
- **Recommended Runbook**: Preemptive throttling of outbound Zoho queues
- **NL Explanation**: *"Predicted anomaly score of 78% is driven by Zoho_CRM integration which recorded 15 consecutive HTTP 504 timeouts, spiking failure rates by +400% over the last 3 minutes. Retry queue exhaustion on Zoho_CRM_Queueable confirms downstream degradation."*

---

## 4. Scenario B — Deployment Correlation (Critical / ~85%)

### Narrative
An administrator deploys a metadata package containing 3 modified Apex classes at 12:00 PM. Starting at 12:02 PM, `System.LimitException` (CPU time limit exceeded) begins firing repeatedly in the `SentinelIncidentTrigger` context. Within 5 minutes, 8 CPU limit exceptions are logged. Simultaneously, 4 integration callouts begin timing out as the trigger consumes available CPU budget.

### Signal Injection

```apex
// Scenario B: Deployment Correlation
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();

// Recent deployment signal
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Deployment',
    Event_Source__c = 'SetupAuditTrail:ApexClass',
    Error_Rate_Delta__c = 0,
    Signal_Value__c = 3,  // 3 classes deployed
    Timestamp__c = DateTime.now().addMinutes(-8)
));

// CPU limit exceptions (8 occurrences)
for (Integer i = 0; i < 8; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Apex',
        Event_Source__c = 'SentinelIncidentTrigger:CPU_TIME_LIMIT',
        Error_Rate_Delta__c = 800.0,
        Signal_Value__c = 10000,  // 10,000ms CPU (limit is 10,000)
        Timestamp__c = DateTime.now().addMinutes(-6 + i)
    ));
}

// Collateral integration timeouts
for (Integer i = 0; i < 4; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Integration',
        Event_Source__c = 'HubSpot_Sync',
        Error_Rate_Delta__c = 300.0,
        Signal_Value__c = 408,
        Timestamp__c = DateTime.now().addMinutes(-5 + i)
    ));
}
```

### Score Calculation Breakdown

| Signal Component | Normalized $S_i$ | Weight $W_i$ | Contribution |
|---|---|---|---|
| Integration Failures (4 × 408, +300%) | 75 | 0.20 | 15.0 |
| Apex Exceptions (8 × CPU limit, +800%) | 98 | 0.20 | 19.6 |
| Deployment Correlation (3 classes, 2 min before spike) | 95 | 0.18 | 17.1 |
| Flow Failures (none) | 0 | 0.15 | 0.0 |
| Error Frequency (12 errors / 5 min) | 80 | 0.10 | 8.0 |
| Retry Exhaustion (moderate) | 45 | 0.07 | 3.15 |
| Business Impact (HubSpot = medium-high) | 70 | 0.05 | 3.5 |
| Tenant Health (severely degraded) | 85 | 0.05 | 4.25 |
| **Total $P_{\text{anomaly}}$** | | | **~85** |

### Expected Results
- **Anomaly Score**: 82–88 (target: ~85)
- **Risk Level**: `Critical`
- **Recommended Runbook**: Initiate metadata rollback checklist and diagnostic comparison report
- **NL Explanation**: *"Predicted anomaly score of 85% is driven by 8 CPU time limit exceptions in SentinelIncidentTrigger beginning 2 minutes after a metadata deployment of 3 Apex classes. Temporal correlation confidence: 95%. Collateral impact detected on HubSpot_Sync integration (+300% failure rate)."*

---

## 5. Scenario C — Flow Exhaustion (Warning / ~55%)

### Narrative
The high-revenue Order Processing Flow begins intermittently faulting. Over 10 minutes, 5 Flow fault logs are recorded. Average active Flow interview durations spike from a baseline of 1.2 seconds to 12.5 seconds, indicating resource contention. No Apex exceptions or deployment changes have occurred.

### Signal Injection

```apex
// Scenario C: Flow Queue Exhaustion
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();

// Flow fault signals (5 occurrences)
for (Integer i = 0; i < 5; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Flow',
        Event_Source__c = 'Order_Processing_Flow',
        Error_Rate_Delta__c = 180.0,
        Signal_Value__c = 12500,  // 12.5 seconds avg duration (ms)
        Timestamp__c = DateTime.now().addMinutes(-10 + (i * 2))
    ));
}

// Elevated tenant health degradation
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Health',
    Event_Source__c = 'Org_Health_Monitor',
    Error_Rate_Delta__c = 40.0,
    Signal_Value__c = 72,  // health score dropped to 72/100
    Timestamp__c = DateTime.now().addMinutes(-2)
));
```

### Score Calculation Breakdown

| Signal Component | Normalized $S_i$ | Weight $W_i$ | Contribution |
|---|---|---|---|
| Integration Failures (none) | 0 | 0.20 | 0.0 |
| Apex Exceptions (none) | 0 | 0.20 | 0.0 |
| Deployment Correlation (none) | 0 | 0.18 | 0.0 |
| Flow Failures (5 faults, +180%, 10× duration) | 88 | 0.15 | 13.2 |
| Error Frequency (5 errors / 10 min) | 55 | 0.10 | 5.5 |
| Retry Exhaustion (none) | 0 | 0.07 | 0.0 |
| Business Impact (Order Processing = high revenue) | 90 | 0.05 | 4.5 |
| Tenant Health (degraded to 72/100) | 55 | 0.05 | 2.75 |
| **Total $P_{\text{anomaly}}$** | | | **~55** |

### Expected Results
- **Anomaly Score**: 52–58 (target: ~55)
- **Risk Level**: `Warning`
- **Recommended Runbook**: Purge stuck Flow interview partitions and pause low-priority background queues
- **NL Explanation**: *"Predicted anomaly score of 55% is driven by Order_Processing_Flow which recorded 5 faults over 10 minutes with average interview duration spiking from 1.2s to 12.5s (+941%). No deployment correlation detected. Business impact is elevated due to revenue-critical flow classification."*

---

## 6. Scenario D — Low-Risk Noise (Info / Below 40%)

### Narrative
Normal operational telemetry is flowing. A single integration endpoint (`Slack_Webhook`) records 2 transient HTTP 429 (rate limit) responses within a 15-minute window. A background retry job succeeds on the second attempt. No error frequency spikes, no Apex exceptions, no Flow faults, and no recent deployments. This scenario validates that the scoring model correctly suppresses noise and does **not** generate false alarms.

### Signal Injection

```apex
// Scenario D: Low-Risk Noise
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();

// Minor integration throttle (2 retryable 429s)
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Integration',
    Event_Source__c = 'Slack_Webhook',
    Error_Rate_Delta__c = 20.0,
    Signal_Value__c = 429,
    Timestamp__c = DateTime.now().addMinutes(-12)
));

signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Integration',
    Event_Source__c = 'Slack_Webhook',
    Error_Rate_Delta__c = 15.0,
    Signal_Value__c = 429,
    Timestamp__c = DateTime.now().addMinutes(-8)
));

// Successful retry confirmation
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Retry',
    Event_Source__c = 'Slack_Webhook_Retry',
    Error_Rate_Delta__c = 0,
    Signal_Value__c = 1,  // 1 retry = success
    Timestamp__c = DateTime.now().addMinutes(-7)
));
```

### Score Calculation Breakdown

| Signal Component | Normalized $S_i$ | Weight $W_i$ | Contribution |
|---|---|---|---|
| Integration Failures (2 × 429, +20% delta, retried) | 18 | 0.20 | 3.6 |
| Apex Exceptions (none) | 0 | 0.20 | 0.0 |
| Deployment Correlation (none) | 0 | 0.18 | 0.0 |
| Flow Failures (none) | 0 | 0.15 | 0.0 |
| Error Frequency (2 errors / 15 min = low) | 12 | 0.10 | 1.2 |
| Retry Exhaustion (recovered on attempt 1) | 5 | 0.07 | 0.35 |
| Business Impact (Slack = low criticality) | 20 | 0.05 | 1.0 |
| Tenant Health (stable at 95/100) | 5 | 0.05 | 0.25 |
| **Total $P_{\text{anomaly}}$** | | | **~6** |

### Expected Results
- **Anomaly Score**: 4–12 (target: ~6)
- **Risk Level**: `Info` (below 40% threshold)
- **Recommended Runbook**: None — signal logged silently
- **NL Explanation**: No prediction card is generated. The signal is recorded in `Sentinel_Anomaly_Signal__c` for historical pattern analysis but does not meet the minimum threshold to create a `Sentinel_Prediction__c` record.
- **Critical Validation**: Confirm that **no prediction card appears** on the dashboard. This scenario is essential for proving the system does not create false alarms from normal operational noise.

---

## 7. Expected Score Ranges

The following matrix summarizes the expected scoring outputs and acceptable tolerance bands for each scenario:

| Scenario | Signal Profile | Target Score | Acceptable Range | Risk Category |
|---|---|---|---|---|
| **A** — API Timeout Spike | 15 × HTTP 504, +400% delta | **~78** | 75–82 | 🔴 Critical |
| **B** — Deployment Correlation | 8 × CPU limit + 3 class deploy | **~85** | 82–88 | 🔴 Critical |
| **C** — Flow Exhaustion | 5 × Flow faults, 10× duration | **~55** | 52–58 | 🟡 Warning |
| **D** — Low-Risk Noise | 2 × HTTP 429, auto-retried | **~6** | 4–12 | 🟢 Info (No Card) |

### Tolerance Validation Rule
If any scenario produces a score **outside** its acceptable range, the scoring weights must be recalibrated and the scenario re-executed before proceeding to subsequent milestones. Scores crossing a threshold boundary (e.g., a Warning scenario scoring ≥70 would incorrectly trigger Critical) constitute a **blocking defect**.

---

## 8. Expected UI States

Each scenario produces a distinct visual state in the glassmorphic prediction cards rendered by the `zentomDashboard` LWC component:

### Scenario A — Critical Card
| Element | Expected State |
|---|---|
| Card Border | Bold crimson pulse animation (`#EF4444`, 2px solid) |
| Risk Badge | `🔴 CRITICAL ANOMALY` — filled red pill with white text |
| Score Display | Large bold `78%` with confidence meter arc filled to ~78% |
| Explanation Panel | Expandable — shows Zoho_CRM timeout details and retry exhaustion |
| Action Buttons | `Approve Preempt Action` (primary) · `Dismiss` (secondary) · `View Details` (tertiary) |
| Governance Banner | *"Advisory Only — Human Clearance Required"* visible above actions |

### Scenario B — Critical Card (Deployment-Correlated)
| Element | Expected State |
|---|---|
| Card Border | Bold crimson pulse animation (`#EF4444`, 2px solid) |
| Risk Badge | `🔴 CRITICAL ANOMALY` — filled red pill |
| Score Display | Large bold `85%` with confidence meter arc filled to ~85% |
| Explanation Panel | Shows deployment timestamp, class names, and CPU exception correlation |
| Deployment Tag | Special `📦 Deployment Correlated` sub-badge visible below risk indicator |
| Action Buttons | `Approve Preempt Action` · `Dismiss` · `View Details` |

### Scenario C — Warning Card
| Element | Expected State |
|---|---|
| Card Border | Warm amber glow (`#F59E0B`, 1.5px solid) |
| Risk Badge | `🟡 WARNING` — amber pill with dark text |
| Score Display | Medium bold `55%` with confidence meter arc filled to ~55% |
| Explanation Panel | Shows Flow fault count, duration spike metrics |
| Action Buttons | `Approve Preempt Action` · `Dismiss` · `View Details` |

### Scenario D — No Card (Suppressed)
| Element | Expected State |
|---|---|
| Card Rendered | **None** — no prediction card appears on the dashboard |
| Signal Log | `Sentinel_Anomaly_Signal__c` records exist in database for audit purposes |
| Dashboard State | Empty prediction panel shows: *"No active predictions. All systems nominal."* |

---

## 9. Expected Operator Actions

Each scenario defines the correct operator response and the resulting system behavior:

### Scenario A — Approve Preempt Action
| Step | Operator Action | System Response |
|---|---|---|
| 1 | Operator clicks **"Approve Preempt Action"** | Controller creates `Sentinel_Incident__c` with `Approval_Status__c = 'Pending Approval'` |
| 2 | Standard approval routing activates | Incident enters Guardian Gate queue via existing trigger automation |
| 3 | Operator approves incident in Guardian Gate | Runbook executes: throttle Zoho outbound queues |
| 4 | — | `Sentinel_Prediction__c.Operator_Decision__c` = `Approved`, `Decision_Timestamp__c` populated |
| 5 | — | `Sentinel_Audit_Log__c` record created with event `PREDICTION_APPROVED` |
| 6 | — | `SentinelFlow_Dashboard_Event__e` published with `Event_Type__c = 'AI_TRACE_UPDATED'` |

### Scenario B — Approve Preempt Action (Deployment Rollback)
| Step | Operator Action | System Response |
|---|---|---|
| 1 | Operator clicks **"Approve Preempt Action"** | Controller creates `Sentinel_Incident__c` for metadata rollback checklist |
| 2 | Approval routing activates | Incident routed for rollback review |
| 3 | — | Prediction status transitions to `Approved` with full audit trail |

### Scenario C — Dismiss (Monitored Acceptance)
| Step | Operator Action | System Response |
|---|---|---|
| 1 | Operator clicks **"Dismiss"** | Prediction card fades out with 300ms CSS transition |
| 2 | — | `Sentinel_Prediction__c.Status__c` = `Dismissed`, `Operator_Decision__c` = `Dismissed` |
| 3 | — | `Sentinel_Audit_Log__c` created with event `PREDICTION_DISMISSED` |
| 4 | — | Scoring engine applies weight penalty ($P = 0.85$) to Flow signal for 24 hours |
| 5 | Operator optionally enters feedback | `Feedback_Comments__c` = *"Expected batch processing window"* |

### Scenario D — No Action Required
| Step | Operator Action | System Response |
|---|---|---|
| 1 | No card is shown | No operator interaction occurs |
| 2 | — | Signal records are silently stored for historical pattern analysis |
| 3 | — | No `Sentinel_Prediction__c` record is created |

---

## 10. Validation Checklist

Every scenario must pass all items in this checklist before the scenario is considered validated. A single failure on any Critical item blocks GA progression.

### Pre-Execution Checks
- [ ] Anonymous Apex script compiles without errors
- [ ] `Savepoint` / `Database.rollback()` wrapper prevents data pollution
- [ ] All `System_Setting__mdt` metadata values match the documented defaults
- [ ] Permission sets (`SentinelFlow_Admin`, `SentinelFlow_Operator`) are assigned to the test user

### Scoring Accuracy (All Scenarios)
- [ ] **Scenario A**: Score falls within 75–82 range
- [ ] **Scenario B**: Score falls within 82–88 range
- [ ] **Scenario C**: Score falls within 52–58 range
- [ ] **Scenario D**: Score falls within 4–12 range (no prediction card created)
- [ ] No scenario crosses a threshold boundary (e.g., Warning scoring as Critical)

### UI State Verification
- [ ] Scenario A renders a Critical card with crimson pulse border
- [ ] Scenario B renders a Critical card with deployment correlation sub-badge
- [ ] Scenario C renders a Warning card with amber glow border
- [ ] Scenario D produces no card; empty state message displays correctly
- [ ] All cards show the governance banner: *"Advisory Only — Human Clearance Required"*
- [ ] Confidence meter arcs are proportionally filled to match the score percentage

### Explainability Verification
- [ ] Each prediction card's NL explanation references specific signal sources by name
- [ ] Each explanation includes quantitative metrics (counts, percentages, timestamps)
- [ ] Deployment-correlated predictions include the temporal offset between deploy and spike
- [ ] No explanation uses vague or unexplained language ("something went wrong")

### Human Governance Boundary
- [ ] "Approve" creates a new `Sentinel_Incident__c` with `Pending Approval` status
- [ ] "Approve" does **not** directly execute any runbook or modify system data
- [ ] "Dismiss" updates `Sentinel_Prediction__c` status without creating an incident
- [ ] No background job, scheduled Apex, or future method can auto-transition prediction status
- [ ] FLS exception is thrown if a user without `SentinelFlow_Operator` attempts to modify `Operator_Decision__c`

### Audit Trail Compliance
- [ ] Every Approve action creates a `Sentinel_Audit_Log__c` record with `PREDICTION_APPROVED`
- [ ] Every Dismiss action creates a `Sentinel_Audit_Log__c` record with `PREDICTION_DISMISSED`
- [ ] Every state change publishes a `SentinelFlow_Dashboard_Event__e` platform event
- [ ] `Operator_User__c` lookup correctly maps to the logged-in user's `Id`
- [ ] `Decision_Timestamp__c` is populated within 1 second of the UI click

### False Alarm Protection
- [ ] Scenario D confirms zero false alarms from normal noise
- [ ] Weight penalty ($P = 0.85$) is applied to the correct signal after a Dismiss action
- [ ] Telemetry cooldown activates after 3 dismissals on the same endpoint within 8 hours

### Governor Limit Safety
- [ ] All scenarios complete within CPU time limits (< 8,000ms per transaction)
- [ ] Bulk signal injection (200+ records) does not exceed DML statement limits
- [ ] No heap size warnings appear in debug logs during scoring evaluation

---

*End of Prediction Sample Signal Scenarios.*
