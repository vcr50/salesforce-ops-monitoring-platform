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
    
    // Milestone 58B Tuned — Scenario B: Deployment + Error/CPU emphasis
    // Projected: S3=100*0.45 + S1=95*0.25 + S5=80*0.20 = 45+23.75+16 = ~84.75% (Critical)
    SystemSettings.setOverride('Prediction_Weight_Deployment', 0.45);
    SystemSettings.setOverride('Prediction_Weight_Error', 0.25);
    SystemSettings.setOverride('Prediction_Weight_Integration', 0.20);
    SystemSettings.setOverride('Prediction_Weight_Retry', 0.04);
    SystemSettings.setOverride('Prediction_Weight_Flow', 0.03);
    SystemSettings.setOverride('Prediction_Weight_Business', 0.015);
    SystemSettings.setOverride('Prediction_Weight_Health', 0.015);
    SystemSettings.setOverride('Prediction_Weight_History', 0.01);
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // Recent deployment signal: 3 classes deployed 8 minutes ago (within 15 min = S3=100)
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Deployment Activity',
        Event_Source__c = 'HubSpot_Sync',
        Metric_Value__c = 8.0,     // 8 minutes since deploy -> S3 = 100
        Severity__c = 'Critical',
        Timestamp__c = DateTime.now()
    ));
    
    // CPU time limit Apex exception errors – high exception rate
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Apex Exception',
        Event_Source__c = 'HubSpot_Sync',
        Metric_Value__c = 95.0,
        Severity__c = 'Critical',
        Timestamp__c = DateTime.now()
    ));
    
    // HubSpot integration timeouts from collateral CPU exhaustion
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Integration Error',
        Event_Source__c = 'HubSpot_Sync',
        Metric_Value__c = 80.0,
        Severity__c = 'Critical',
        Timestamp__c = DateTime.now()
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' deployment correlation mock signals.');
    
    System.debug('Invoking SentinelPredictionEngine.processSignals()...');
    SentinelPredictionEngine.processSignals(signals);
    
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Prediction_Score__c, Status__c, Summary__c, Explanation__c, Operator_Decision__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY
        ORDER BY CreatedDate DESC, Prediction_Score__c DESC
        LIMIT 5
    ];
    
    System.debug('=== SCENARIO B EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[ERROR] No prediction card generated for Scenario B! Check threshold levels.');
    } else {
        for (Sentinel_Prediction__c p : predictions) {
            System.debug('Prediction ID: ' + p.Id);
            System.debug('Anomaly Score: ' + p.Prediction_Score__c + '%');
            System.debug('Risk Level: ' + p.Status__c);
            System.debug('Summary: ' + p.Summary__c);
            System.debug('Explanation: ' + p.Explanation__c);
        }
    }
    
} catch (Exception e) {
    System.debug('[ERROR] Scenario B Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
    System.debug('Scenario B completed. Database rolled back to preserve sandbox state.');
}
