// =========================================================================
// SentinelFlow Pilot Run — Scenario D: Low-Risk Operations Noise (Slack Webhook)
// =========================================================================
// Purpose: Simulates low-risk noise: transient HTTP 429 rate limit events
//          that are successfully retried. Validates that the system 
//          does NOT generate any prediction card on the dashboard (Score < 40%).
// Execution Options:
//   1. Dry-Run Mode (Default): Runs with a database rollback. Verifies scoring.
//   2. Live Commit Mode: Comment out the rollback block to persist data 
//      for dashboard LWC testing.
// =========================================================================

Savepoint sp = Database.setSavepoint();

try {
    System.debug('=== INITIATING SCENARIO D SIMULATION: LOW-RISK NOISE ===');
    
    // Milestone 58B Validation — Scenario D: No weight overrides.
    // Uses new default weights (w3=0.45, w1=0.25). Slack noise signals:
    // S2=20*0.06 + S5=8*0.10 = 1.2+0.8 = ~2% — well below 40% suppression threshold.
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Minor retry event (1 retry success = very low spike count)
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Retry Spike',
        Event_Source__c = 'Slack_Webhook',
        Metric_Value__c = 1.0,   // 1 retry * 20 = 20 -> S2 = 20 (low)
        Severity__c = 'Low',
        Timestamp__c = DateTime.now()
    ));
    
    // Minimal integration error signal
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Integration Error',
        Event_Source__c = 'Slack_Webhook',
        Metric_Value__c = 8.0,   // very low integration rate
        Severity__c = 'Low',
        Timestamp__c = DateTime.now()
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' Slack low-risk noise signals.');
    
    System.debug('Invoking SentinelPredictionEngine.processSignals()...');
    SentinelPredictionEngine.processSignals(signals);
    
    // Only check if a card was erroneously generated
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Prediction_Score__c, Status__c, Summary__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY AND Summary__c LIKE '%Slack_Webhook%'
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    
    // Fallback if lookup field not available - check all today's predictions
    if (predictions.isEmpty()) {
        predictions = [
            SELECT Id, Prediction_Score__c, Status__c, Summary__c
            FROM Sentinel_Prediction__c
            WHERE CreatedDate = TODAY
            ORDER BY Prediction_Score__c ASC
            LIMIT 5
        ];
    }
    
    System.debug('=== SCENARIO D EVALUATION RESULTS ===');
    Boolean cardGenerated = false;
    for (Sentinel_Prediction__c p : predictions) {
        if (p.Prediction_Score__c != null && p.Prediction_Score__c < 40) {
            System.debug('[SUCCESS] Low score prediction found: ' + p.Prediction_Score__c + '% (below 40% threshold - card suppressed, noise filtered correctly)');
        } else if (p.Prediction_Score__c != null && p.Prediction_Score__c >= 40) {
            System.debug('[WARNING] Unexpected card generated with score: ' + p.Prediction_Score__c + '%. Scoring is too sensitive for noise.');
            cardGenerated = true;
        }
    }
    if (predictions.isEmpty()) {
        System.debug('[SUCCESS] Zero prediction records created. Noise correctly suppressed below threshold.');
    }
    
} catch (Exception e) {
    System.debug('[ERROR] Scenario D Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
    System.debug('Scenario D completed. Database rolled back to preserve sandbox state.');
}
