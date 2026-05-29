# SentinelFlow Prediction Engine Apex Service Design (Milestone 54D)

**Date**: 2026-05-30  
**Author**: TomCodeX Engineering  
**Status**: Proposal  
**Version**: 1.0  

---

## 1. Purpose

The purpose of this document is to design the technical architecture and interfaces of the **Apex Service Layer** for the SentinelFlow Prediction Engine. This layer is responsible for querying incoming telemetry signals, computing prediction scores, generating natural language explainability output, and creating prediction records within governor limits.

---

## 2. Service Class Responsibilities

We will introduce four primary Apex classes to handle predictions modularly:

```
               ┌───────────────────────────────┐
               │  SentinelPredictionEngine     │
               │   (Central Coordinator)       │
               └───────────────┬───────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  Scoring     │       │ Explanation  │       │  Trigger/    │
│  Service     │       │  Service     │       │  Batch Job   │
└──────────────┘       └──────────────┘       └──────────────┘
```

1.  **`SentinelPredictionEngine.cls`**: The main coordinator. It manages the orchestrations of querying raw signal anomalies, calling the scoring service, requesting natural language explanations, and executing bulk DML inserts.
2.  **`SentinelPredictionScoringService.cls`**: The mathematical engine. It calculates Anomaly Probability and Model Confidence scores based on the signal matrix and metadata settings.
3.  **`SentinelPredictionExplanationService.cls`**: The explainability service. It maps telemetry metrics and deployment correlations into structured, human-readable descriptions.
4.  **`SentinelPredictionEngineTest.cls`**: The unit test class containing mocks and assertions to verify execution correctness and governor limit safety.

---

## 3. Input Signal Query Strategy

To prevent performance degradation in large-scale orgs:
*   **Windowed Telemetry Queries**: The service queries telemetry logs (`Integration_Log__c`, Apex Exceptions, etc.) and Setup Audit Trail records in rolling 5-to-15 minute windows.
*   **Indexed Queries**: All SOQL filters bind to index-backed datetime fields (`CreatedDate`, `Timestamp__c`) to guarantee fast retrieval and prevent table scans.
*   **Selective Ingestion**: The engine only ingests records flagged as anomalous (e.g. HTTP status $\ge 400$, or exceptions) during the rolling window.

---

## 4. Scoring Service Design (`SentinelPredictionScoringService`)

The scoring service performs calculations in memory:
*   **Interface**:
    ```apex
    public class ScoringInput {
        public Decimal errorVelocity;
        public Integer retrySpikeCount;
        public Integer minutesSinceDeployment;
        public Integer flowFailureCount;
        public Decimal integrationFailureRate;
        public Decimal businessImpactScore;
        public Decimal historicalRecurrenceFactor;
        public Decimal orgHealthDegradationRate;
    }
    
    public class ScoringResult {
        public Decimal probabilityScore;
        public Decimal confidenceScore;
    }
    ```
*   **Logic**:
    - Normalizes each input property to a 0-100 scale.
    - Retrieves weights dynamically from `SystemSettings.cls` with static fallback defaults.
    - Multiplies inputs by weights and sums the result to calculate $P_{\text{anomaly}}$.
    - Computes confidence decay based on data completeness.

---

## 5. Prediction Record Creation & In-Memory Linkage

*   **Threshold Gates**: To prevent database clutter, the engine only inserts a `Sentinel_Prediction__c` record if $P_{\text{anomaly}} \ge 40\%$ (Warning or Critical states). Low-level anomaly signals ($< 40\%$) are logged silently without generating parent prediction records.
*   **Relationship Linkage**: 
    - The engine first inserts the parent `Sentinel_Prediction__c` records in bulk.
    - It then maps the generated IDs back to the child `Sentinel_Anomaly_Signal__c` records.
    - Finally, it executes a bulk update on the child signals to establish the lookup relationship.

---

## 6. Explanation Generation (`SentinelPredictionExplanationService`)

Generates structured text detailing calculations:
*   **Template Interpolator**: Uses token replacement to output strings like:
    ```
    "Outage probability is 75% (Confidence: 85%) because a metadata deployment occurred 12 minutes ago and HTTP timeout counts spiked by 400% on endpoint /api/v1/payments."
    ```
*   **Dynamic Language Mapping**: The service cycles through contributing signals and appends a sentence for each signal exceeding its warning threshold ($S_i \ge 40$).

---

## 7. Bulkification Strategy

The service is fully bulkified to prevent governor limit exceptions:
*   **Collection-Based Processing**: Loops process lists of signals, avoiding DML or SOQL queries inside `for` loops.
*   **Single DML operations**: Parent predictions and child signals are accumulated and written to the database using single, bulked DML `insert` and `update` commands.
*   **Queueable Execution**: Heavy scoring routines run asynchronously inside a Queueable Apex job (`SentinelPredictionQueueable.cls`) to provide separate, high-limit CPU envelopes.

---

## 8. Error Handling

*   **Try-Catch Enclosures**: All telemetry queries and scoring routines are enclosed in try-catch blocks.
*   **Graceful Failures**: If a query or calculation fails (e.g. metadata lock or CPU timeout), the transaction is not rolled back. The system catches the exception, writes an error log to `Sentinel_Error_Log__c`, and logs a warning in the system.
*   **Self-Healing Fallbacks**: If the scoring engine fails, the prediction status defaults to a safe, uncalculated state rather than crashing operations.

---

## 9. Test Strategy (`SentinelPredictionEngineTest`)

*   **Mocking Framework**: The test class uses mock telemetry data and simulated Setup Audit Trail records to run unit tests without relying on database-level state.
*   **Precision Math Verification**: Asserts that calculations match expected outputs under standard configurations and metadata overrides.
*   **Bulk Assertions**: Verifies that lists of 200+ signals are processed successfully in a single transaction.
*   **Governor Limit Assertions**: Asserts that CPU usage is $< 50\text{ms}$ and SOQL queries count is $< 10$ per transaction.

---

## 10. Security & Governance Rules

*   **Strict Sharing**: All service classes run `with sharing` to enforce Salesforce record-level sharing and security boundaries.
*   **FLS Enforcement**: All database writes use `Security.stripInaccessible` or `WITH USER_MODE` to guarantee Field-Level Security compliance.
*   **No Autonomous Edits**: Predictions only recommend and warn. Mitigations still require human clearance.
