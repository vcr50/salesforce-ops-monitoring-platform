// =========================================================================
// SentinelFlow Pilot Run — Scenario B: Recent Deployment Correlation (CPU Limit)
// =========================================================================
// Purpose: Simulates a high-priority correlation event where a metadata 
//          deployment is immediately followed by high-frequency CPU time 
//          limit exceptions in a key trigger, causing HubSpot timeouts.
// Execution Options:
//   1. Dry-Run Mode (Default): Runs with a database rollback. Verifies scoring.
//   2. Live Commit Mode: Comment out the rollback block to persist data 
//      for dashboard LWC testing.
// =========================================================================

Savepoint sp = Database.setSavepoint();

try {
    System.debug('=== INITIATING SCENARIO B SIMULATION: DEPLOYMENT CORRELATION ===');
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Recent deployment signal: 3 Apex classes deployed 8 minutes ago
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Deployment',
        Event_Source__c = 'SetupAuditTrail:ApexClass',
        Error_Rate_Delta__c = 0.0,
        Signal_Value__c = 3.0,
        Timestamp__c = DateTime.now().addMinutes(-8)
    ));
    
    // Inject 8 CPU time limit exceptions logged inside SentinelIncidentTrigger
    for (Integer i = 0; i < 8; i++) {
        signals.add(new Sentinel_Anomaly_Signal__c(
            Signal_Type__c = 'Apex',
            Event_Source__c = 'SentinelIncidentTrigger:CPU_TIME_LIMIT',
            Error_Rate_Delta__c = 800.0,
            Signal_Value__c = 10000.0, // 10,000ms CPU (max limit reached)
            Timestamp__c = DateTime.now().addMinutes(-6 + i)
        ));
    }
    
    // Inject 4 collateral integration timeouts logged on HubSpot sync
    for (Integer i = 0; i < 4; i++) {
        signals.add(new Sentinel_Anomaly_Signal__c(
            Signal_Type__c = 'Integration',
            Event_Source__c = 'HubSpot_Sync',
            Error_Rate_Delta__c = 300.0,
            Signal_Value__c = 408, // Request Timeout
            Timestamp__c = DateTime.now().addMinutes(-5 + i)
        ));
    }
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' mock correlation signals.');
    
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
    
    System.debug('=== SCENARIO B EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[ERROR] No prediction card generated for Scenario B! Check threshold levels.');
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
    System.debug('[ERROR] Scenario B Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    // Keep this rollback block active for dry-run testing.
    // Comment it out if you want to push signals to the live dashboard!
    Database.rollback(sp);
    System.debug('Scenario B completed. Database rolled back to preserve sandbox state.');
}
