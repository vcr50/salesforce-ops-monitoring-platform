// =========================================================================
// SentinelFlow Pilot Run — Scenario C: Flow Queue Exhaustion (Order Processing)
// =========================================================================
// Purpose: Simulates a Warning-level anomaly on a revenue-critical process
//          (Order_Processing_Flow) recording intermittent faults and 
//          severe execution duration degradation.
// Execution Options:
//   1. Dry-Run Mode (Default): Runs with a database rollback. Verifies scoring.
//   2. Live Commit Mode: Comment out the rollback block to persist data 
//      for dashboard LWC testing.
// =========================================================================

Savepoint sp = Database.setSavepoint();

try {
    System.debug('=== INITIATING SCENARIO C SIMULATION: FLOW EXHAUSTION ===');
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Inject 5 Flow fault records over 10 minutes with average durations of 12.5s
    for (Integer i = 0; i < 5; i++) {
        signals.add(new Sentinel_Anomaly_Signal__c(
            Signal_Type__c = 'Flow',
            Event_Source__c = 'Order_Processing_Flow',
            Error_Rate_Delta__c = 180.0,
            Signal_Value__c = 12500.0, // 12.5s average duration (ms)
            Timestamp__c = DateTime.now().addMinutes(-10 + (i * 2))
        ));
    }
    
    // Inject elevated tenant health degradation from health monitor
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Health',
        Event_Source__c = 'Org_Health_Monitor',
        Error_Rate_Delta__c = 40.0,
        Signal_Value__c = 72.0, // health score dropped to 72/100
        Timestamp__c = DateTime.now().addMinutes(-2)
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' mock Flow signals.');
    
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
    
    System.debug('=== SCENARIO C EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[ERROR] No prediction card generated for Scenario C! Check threshold levels.');
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
    System.debug('[ERROR] Scenario C Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    // Keep this rollback block active for dry-run testing.
    // Comment it out if you want to push signals to the live dashboard!
    Database.rollback(sp);
    System.debug('Scenario C completed. Database rolled back to preserve sandbox state.');
}
