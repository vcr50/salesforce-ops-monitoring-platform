# SentinelFlow Prediction Pilot Signal Simulation Setup (Milestone 57B)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Approved  
**Version**: 1.0  
**Target Environment**: `vjdev@asap.com`  

---

> [!IMPORTANT]
> **GOVERNANCE MANDATE: STRICT ADVISORY MODE**
> The executable scripts provided below trigger predictions, alerts, and recommended runbooks in real-time. No automated action is ever performed by the backend engine. All execution steps remain **advisory-only**. The pilot operator must manually approve or dismiss each generated card to verify model performance and capture structured feedback.

---

## 1. Purpose

To rigorously test the SentinelFlow Prediction Engine against the established success criteria of the rolling Pilot Run, operators must be equipped with realistic, reproducible, and isolated signal triggers.

This document details the executable anonymous Apex scripts and simulation architectures designed for **Milestone 57B**. These scripts inject controlled multi-variable telemetry streams representing four canonical operational scenarios. These scenarios exercise the complete prediction pipeline: from raw signal creation (`Sentinel_Anomaly_Signal__c`) and asynchronous linear scoring evaluation (`SentinelPredictionEngine`), to real-time LWC dashboard card rendering and human-in-the-loop operator feedback tracking.

---

## 2. Execution Instructions & Salesforce CLI Commands

All pilot simulations are designed as anonymous Apex scripts located inside the package directory under [scripts/apex/](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/). These scripts can be executed directly using the Salesforce CLI.

### Prerequisites:
- Assign the `SentinelFlow_Admin` or `SentinelFlow_Operator` permission set to your developer sandbox user profile in `vjdev@asap.com`.
- Open the SentinelFlow Command Center in your browser to monitor real-time platform event feeds.

### Executing via Salesforce CLI (Modern sf CLI):

```powershell
# 1. Execute Scenario A (API Timeout Spike) in Dry-Run Mode
sf apex run execute --file scripts/apex/simulate_pilot_scenario_a.apex --target-org vjdev@asap.com

# 2. Execute Scenario B (Deployment Correlation) in Dry-Run Mode
sf apex run execute --file scripts/apex/simulate_pilot_scenario_b.apex --target-org vjdev@asap.com

# 3. Execute Scenario C (Flow Exhaustion) in Dry-Run Mode
sf apex run execute --file scripts/apex/simulate_pilot_scenario_c.apex --target-org vjdev@asap.com

# 4. Execute Scenario D (Slack Webhook Noise) in Dry-Run Mode
sf apex run execute --file scripts/apex/simulate_pilot_scenario_d.apex --target-org vjdev@asap.com
```

### Executing via Legacy SFDX CLI:
```powershell
sfdx force:apex:execute -f scripts/apex/simulate_pilot_scenario_a.apex -u vjdev@asap.com
```

---

## 3. Scenario A — API Timeout Spike (Zoho_CRM)

### Failure Description:
A downstream CRM endpoint (`Zoho_CRM`) begins failing due to Gateway Timeout responses. The telemetry logs record 15 consecutive HTTP 504 errors within 3 minutes. The log failure delta spikes by **+400%** over the rolling hourly baseline. Zoho's processing queueable begins retrying, leading to queueable exhaustion.

```
       +--------------------------------------------------------+
       | Zoho_CRM HTTP 504 Timeout Event Spikes (15 occurrences)|
       +--------------------------------------------------------+
                                   |
                                   v
       +--------------------------------------------------------+
       |   Zoho_CRM_Queueable Retry Exhaustion (+250% delta)   |
       +--------------------------------------------------------+
                                   |
                                   v
       +--------------------------------------------------------+
       |   SentinelPredictionEngine Scoring Run calculates:      |
       |   Anomaly Score = ~78% (Risk Tier: Critical)           |
       +--------------------------------------------------------+
```

### Simulation Code Block:
The full source is located in [simulate_pilot_scenario_a.apex](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/simulate_pilot_scenario_a.apex):

```apex
// Extract from scripts/apex/simulate_pilot_scenario_a.apex
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
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Retry',
    Event_Source__c = 'Zoho_CRM_Queueable',
    Error_Rate_Delta__c = 250.0,
    Signal_Value__c = 5,
    Timestamp__c = DateTime.now().addMinutes(-1)
));
```

### Expected Prediction Output:
*   **Anomaly Score**: $75\% - 82\%$ (Scoring target: **$78\%$**).
*   **Risk Level**: `Critical` (🔴 Pulse crimson glassmorphic card).
*   **Recommended Runbook**: *"Preemptive Throttling of Zoho outbound queues & Administrator notifications."*
*   **NL Explanation**: *"Predicted anomaly score of 78% is driven by Zoho_CRM integration which recorded 15 consecutive HTTP 504 timeouts, spiking failure rates by +400% over the last 3 minutes. Retry queue exhaustion on Zoho_CRM_Queueable confirms downstream degradation."*

---

## 4. Scenario B — Deployment Correlation (Apex CPU Limit)

### Failure Description:
A Salesforce metadata package containing 3 modified Apex classes is deployed at 12:00 PM. Immediately at 12:02 PM, high-frequency `System.LimitException` (CPU time limit exceeded) exceptions are thrown repeatedly within `SentinelIncidentTrigger` on transactional operations. HubSpot callouts begin timing out because trigger loops exhaust the CPU allocation.

### Simulation Code Block:
The full source is located in [simulate_pilot_scenario_b.apex](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/simulate_pilot_scenario_b.apex):

```apex
// Extract from scripts/apex/simulate_pilot_scenario_b.apex
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Deployment',
    Event_Source__c = 'SetupAuditTrail:ApexClass',
    Error_Rate_Delta__c = 0.0,
    Signal_Value__c = 3.0,
    Timestamp__c = DateTime.now().addMinutes(-8)
));
for (Integer i = 0; i < 8; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Apex',
        Event_Source__c = 'SentinelIncidentTrigger:CPU_TIME_LIMIT',
        Error_Rate_Delta__c = 800.0,
        Signal_Value__c = 10000.0,
        Timestamp__c = DateTime.now().addMinutes(-6 + i)
    ));
}
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

### Expected Prediction Output:
*   **Anomaly Score**: $82\% - 88\%$ (Scoring target: **$85\%$**).
*   **Risk Level**: `Critical` (🔴 Pulse crimson glassmorphic card).
*   **Special Tag**: `📦 Deployment Correlated` badge rendered below risk label.
*   **Recommended Runbook**: *"Initiate metadata rollback checklist and generate comparison reports."*
*   **NL Explanation**: *"Predicted anomaly score of 85% is driven by 8 CPU time limit exceptions in SentinelIncidentTrigger beginning 2 minutes after a metadata deployment of 3 Apex classes. Temporal correlation confidence: 95%. Collateral impact detected on HubSpot_Sync integration (+300% failure rate)."*

---

## 5. Scenario C — Flow Exhaustion (Order Processing)

### Failure Description:
The revenue-critical Order Processing Flow begins intermittently faulting. Over a 10-minute window, 5 Flow fault events are logged, and average interview duration degrades from a baseline of $1.2$ seconds to $12.5$ seconds, indicating resource exhaustion. Org health score drops to $72/100$.

### Simulation Code Block:
The full source is located in [simulate_pilot_scenario_c.apex](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/simulate_pilot_scenario_c.apex):

```apex
// Extract from scripts/apex/simulate_pilot_scenario_c.apex
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
for (Integer i = 0; i < 5; i++) {
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Flow',
        Event_Source__c = 'Order_Processing_Flow',
        Error_Rate_Delta__c = 180.0,
        Signal_Value__c = 12500.0,
        Timestamp__c = DateTime.now().addMinutes(-10 + (i * 2))
    ));
}
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Health',
    Event_Source__c = 'Org_Health_Monitor',
    Error_Rate_Delta__c = 40.0,
    Signal_Value__c = 72.0,
    Timestamp__c = DateTime.now().addMinutes(-2)
));
```

### Expected Prediction Output:
*   **Anomaly Score**: $52\% - 58\%$ (Scoring target: **$55\%$**).
*   **Risk Level**: `Warning` (🟡 Warm amber glow card).
*   **Recommended Runbook**: *"Purge stuck Flow interview partitions and pause low-priority background queues."*
*   **NL Explanation**: *"Predicted anomaly score of 55% is driven by Order_Processing_Flow which recorded 5 faults over 10 minutes with average interview duration spiking from 1.2s to 12.5s (+941%). No deployment correlation detected. Business impact is elevated due to revenue-critical flow classification."*

---

## 6. Scenario D — Low-Risk Noise (Slack Integration)

### Failure Description:
Normal operations are running. A low-priority Slack webhook endpoint logs 2 transient HTTP 429 (rate limit) responses within 15 minutes. A background queue retry job succeeds on the first attempt, self-healing the error.

### Simulation Code Block:
The full source is located in [simulate_pilot_scenario_d.apex](file:///d:/TomCodeX%20Inc/SentinelFlow/scripts/apex/simulate_pilot_scenario_d.apex):

```apex
// Extract from scripts/apex/simulate_pilot_scenario_d.apex
List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
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
signals.add(new Sentinel_Anomaly_Signal__c(
    Signal_Type__c = 'Retry',
    Event_Source__c = 'Slack_Webhook_Retry',
    Error_Rate_Delta__c = 0.0,
    Signal_Value__c = 1.0,
    Timestamp__c = DateTime.now().addMinutes(-7)
));
```

### Expected Prediction Output:
*   **Anomaly Score**: $4\% - 12\%$ (Scoring target: **$6\%$**).
*   **Risk Level**: `Info` (Silently logged in database).
*   **UI Dashboard Validation**: **No card is rendered**. Dashboard empty state shows *"No active predictions. All systems nominal."* This validates the model's noise suppression capabilities.

---

## 7. Cleanup & Transaction Safety Strategy

To avoid polluting the sandbox database during iterative pilot runs, the simulation Apex scripts support two execution modes.

### Mode 1 — Transactional Dry-Run (Default):
By wrapping the simulation blocks in a `Savepoint` and executing an explicit `Database.rollback()` inside the `finally` block, the signals and prediction records are calculated, validated, and logged to `System.debug()` without permanently writing records to the database.

```apex
Savepoint sp = Database.setSavepoint();
try {
    // ... Inject signals and invoke engine ...
} finally {
    Database.rollback(sp);
    System.debug('Database rolled back to preserve sandbox state.');
}
```

### Mode 2 — Live Commit (Live Pilot Phase):
To test the visual interactions, animations, and feedback collection features inside the glassmorphic LWC Command Center dashboard, operators must persist the calculations. 
- To enable this, simply **comment out** the `Database.rollback(sp);` line at the bottom of the desired Apex file.
- The records will be committed, publishing `SentinelFlow_Dashboard_Event__e` events and rendering cards instantly.

### Manual Database Cleanup Commands:
If live signals were committed, administrators can purge all pilot records from the sandbox at any time by executing the following database cleanup snippet:

```apex
// purging script: execute via anonymous Apex console
Savepoint sp = Database.setSavepoint();
try {
    List<Sentinel_Anomaly_Signal__c> signals = [SELECT Id FROM Sentinel_Anomaly_Signal__c WHERE CreatedDate = TODAY];
    List<Sentinel_Prediction__c> predictions = [SELECT Id FROM Sentinel_Prediction__c WHERE CreatedDate = TODAY];
    List<Sentinel_Audit_Log__c> audits = [SELECT Id FROM Sentinel_Audit_Log__c WHERE CreatedDate = TODAY];
    
    delete audits;
    delete predictions;
    delete signals;
    
    System.debug('Purged ' + signals.size() + ' signals, ' + predictions.size() + ' predictions, and ' + audits.size() + ' audit logs.');
} catch (Exception e) {
    Database.rollback(sp);
    System.debug('Purge failed: ' + e.getMessage());
}
```

---

## 8. Feedback Modal & Dashboard UI Validation Steps

Once a live simulation has been committed and is visible in the glassmorphic dashboard Command Center, SRE operators must execute the following steps to validate feedback capture:

```
+------------------------------------------------------------------------------------------------+
| LWC CARD VISIBLE: Zoho_CRM Timeout Alert (Score: 78%)                                          |
+------------------------------------------------------------------------------------------------+
|  Step 1: Expand Card -> Verify natural language explanation details Zoho retry exhaustion.      |
|  Step 2: Hover over confidence arc -> Verify numerical percentage maps to Zoho timeouts.       |
|  Step 3: Click "Dismiss" -> Confirm that the feedback dialog overlay is displayed:             |
|                                                                                                |
|          [ Planned Maintenance / Batch Jobs                    ] V                             |
|          Comments: "Downstream Zoho sandbox was slow due to batch data run."                  |
|                                                                                                |
|  Step 4: Click "Confirm Dismiss" -> Verify that the card fades out with 300ms transition.      |
|  Step 5: Query Sentinel_Prediction__c -> Verify Status = 'Dismissed' and Dismissal_Reason__c.  |
|  Step 6: Query Sentinel_Audit_Log__c -> Verify audit record exists with event PREDICTION_DISMISSED |
+------------------------------------------------------------------------------------------------+
```

---

## 9. Tuning Log & Suggestion Check

For Scenario B (Deployment Correlation CPU Limit) and Scenario C (Flow Exhaustion), verify that the automated root-cause analysis (RCA) pipeline generates correct suggestions:
1.  Verify that an entry is programmatically added to `Sentinel_Error_Log__c` with a `Log_Type__c` of `'PREDICTIVE_TUNING_SUGGESTION'`.
2.  Review the `Error_Message__c` and `Stack_Trace__c` fields to confirm they contain the calculated coefficient adjustments ($G_i$) proposed to raise predictive sensitivity.

---

## 10. Verification Success Checklist

Every pilot scenario must satisfy all criteria in this checklist to be considered validated:

- [ ] **Scenario A compiles and executes**: Command completed successfully via `sf apex run execute`.
- [ ] **Scenario A scoring accuracy**: Anomaly score is within $75\% - 82\%$ range.
- [ ] **Scenario B compiles and executes**: Command completed successfully.
- [ ] **Scenario B scoring accuracy**: Anomaly score is within $82\% - 88\%$ range.
- [ ] **Scenario C compiles and executes**: Command completed successfully.
- [ ] **Scenario C scoring accuracy**: Anomaly score is within $52\% - 58\%$ range.
- [ ] **Scenario D compiles and executes**: Command completed successfully.
- [ ] **Scenario D noise suppression**: Anomaly score is $< 15\%$, and **no prediction card is rendered**.
- [ ] **Dry-Run rollback safety**: Executing scripts in default dry-run mode leaves zero records in sandbox databases.
- [ ] **Live Commit event generation**: Executing scripts in live mode correctly publishes events and renders dashboard cards.
- [ ] **Qualitative Comments Capture**: Dismissing cards in live mode correctly populates picklists and textareas on `Sentinel_Prediction__c`.
- [ ] **Governor Limit Compliance**: Script executions consume less than $800$ milliseconds of CPU time.

---

*End of Prediction Pilot Signal Simulation Setup.*
