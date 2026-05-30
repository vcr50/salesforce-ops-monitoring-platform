// =========================================================================
// SentinelFlow Pilot Run — Scenario A: API Endpoint Timeout Spike (Zoho_CRM)
// =========================================================================
// Purpose: Simulates a downstream integration gateway timeout failure chain
//          on the Zoho_CRM endpoint. Generates 15 consecutive HTTP 504
//          timeouts and an integration queue retry event.
// Execution Options:
//   1. Dry-Run Mode (Default): Runs with a database rollback. Verifies scoring.
//   2. Live Commit Mode: Comment out the rollback block to persist data 
//      for dashboard LWC testing.
// =========================================================================

Savepoint sp = Database.setSavepoint();

try {
    System.debug('=== INITIATING SCENARIO A SIMULATION: ZOHO CRM TIMEOUT SPIKE ===');
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Inject 15 consecutive HTTP 504 timeouts across a rolling 3-minute window
    for (Integer i = 0; i < 15; i++) {
        signals.add(new Sentinel_Anomaly_Signal__c(
            Signal_Type__c = 'Integration',
            Event_Source__c = 'Zoho_CRM',
            Error_Rate_Delta__c = 400.0,
            Signal_Value__c = 504,
            Timestamp__c = DateTime.now().addMinutes(-3 + i)
        ));
    }
    
    // Inject supporting context: Zoho queueable retry exhaustion event
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Retry',
        Event_Source__c = 'Zoho_CRM_Queueable',
        Error_Rate_Delta__c = 250.0,
        Signal_Value__c = 5,
        Timestamp__c = DateTime.now().addMinutes(-1)
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' Zoho CRM mock telemetry signals.');
    
    // Invoke Sentinel Prediction Engine to calculate scoring and create prediction record
    System.debug('Invoking SentinelPredictionEngine.evaluate()...');
    SentinelPredictionEngine.evaluate();
    
    // Query and output calculated prediction details
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Anomaly_Score__c, Risk_Level__c, Summary__c,
               Recommended_Runbook__c, Status__c, Operator_Decision__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY
        ORDER BY CreatedDate DESC, Anomaly_Score__c DESC
        LIMIT 5
    ];
    
    System.debug('=== SCENARIO A EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[ERROR] No prediction card generated for Scenario A! Check threshold levels.');
    } else {
        for (Sentinel_Prediction__c p : predictions) {
            System.debug('Prediction ID: ' + p.Id);
            System.debug('Anomaly Score: ' + p.Anomaly_Score__c + '%');
            System.debug('Risk Level: ' + p.Risk_Level__c);
            System.debug('Summary: ' + p.Summary__c);
            System.debug('Recommended Runbook: ' + p.Recommended_Runbook__c);
        }
    }
    
} catch (Exception e) {
    System.debug('[ERROR] Scenario A Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    // Keep this rollback block active for dry-run testing.
    // Comment it out if you want to push signals to the live dashboard!
    Database.rollback(sp);
    System.debug('Scenario A completed. Database rolled back to preserve sandbox state.');
}
