// =========================================================================
// SentinelFlow Pilot Run — Scenario D: Low-Risk Operations Noise (Slack Webhook)
// =========================================================================
// Purpose: Simulates low-risk noise: transient HTTP 429 rate limit events
//          that are successfully retried. Validates that the system 
//          does not generate any prediction card on the dashboard (Score < 40%).
// Execution Options:
//   1. Dry-Run Mode (Default): Runs with a database rollback. Verifies scoring.
//   2. Live Commit Mode: Comment out the rollback block to persist data 
//      for dashboard LWC testing.
// =========================================================================

Savepoint sp = Database.setSavepoint();

try {
    System.debug('=== INITIATING SCENARIO D SIMULATION: LOW-RISK NOISE ===');
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Inject minor integration throttles: 2 retryable HTTP 429s on Slack_Webhook
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
    
    // Inject successful retry event
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Retry',
        Event_Source__c = 'Slack_Webhook_Retry',
        Error_Rate_Delta__c = 0.0,
        Signal_Value__c = 1.0, // 1 retry = success
        Timestamp__c = DateTime.now().addMinutes(-7)
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' mock low-risk noise signals.');
    
    // Invoke Sentinel Prediction Engine to calculate scoring and create prediction record
    System.debug('Invoking SentinelPredictionEngine.evaluate()...');
    SentinelPredictionEngine.evaluate();
    
    // Query and output calculated prediction details
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Anomaly_Score__c, Risk_Level__c, Summary__c, Status__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY AND Anomaly_Score__c >= 40.0
        ORDER BY CreatedDate DESC
    ];
    
    System.debug('=== SCENARIO D EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[SUCCESS] As expected, no prediction card was generated. Normal noise suppressed.');
    } else {
        System.debug('[WARNING] Unexpected prediction card created! Scoring is too sensitive.');
        for (Sentinel_Prediction__c p : predictions) {
            System.debug('Prediction ID: ' + p.Id + ' | Score: ' + p.Anomaly_Score__c + '% | Risk: ' + p.Risk_Level__c);
        }
    }
    
} catch (Exception e) {
    System.debug('[ERROR] Scenario D Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    // Keep this rollback block active for dry-run testing.
    // Comment it out if you want to push signals to the live dashboard!
    Database.rollback(sp);
    System.debug('Scenario D completed. Database rolled back to preserve sandbox state.');
}
