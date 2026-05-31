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
    
    // Milestone 58B Tuned — Scenario C: Flow exhaustion emphasis (Warning-level)
    // Projected: S4=80*0.50 + S1=75*0.20 + S8*0.15 = 40+15+0 = ~55% (Warning)
    SystemSettings.setOverride('Prediction_Weight_Flow', 0.50);
    SystemSettings.setOverride('Prediction_Weight_Error', 0.20);
    SystemSettings.setOverride('Prediction_Weight_Health', 0.15);
    SystemSettings.setOverride('Prediction_Weight_Deployment', 0.05);
    SystemSettings.setOverride('Prediction_Weight_Integration', 0.05);
    SystemSettings.setOverride('Prediction_Weight_Retry', 0.03);
    SystemSettings.setOverride('Prediction_Weight_Business', 0.01);
    SystemSettings.setOverride('Prediction_Weight_History', 0.01);
    
    List<Sentinel_Anomaly_Signal__c> signals = new List<Sentinel_Anomaly_Signal__c>();
    
    // 8 Flow failure events on Order Processing Flow
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Flow Failure',
        Event_Source__c = 'Order_Processing_Flow',
        Metric_Value__c = 8.0,    // 8 fault events -> S4 = 80
        Severity__c = 'Medium',
        Timestamp__c = DateTime.now()
    ));
    
    // Elevated error velocity from stuck interviews
    signals.add(new Sentinel_Anomaly_Signal__c(
        Signal_Type__c = 'Apex Exception',
        Event_Source__c = 'Order_Processing_Flow',
        Metric_Value__c = 75.0,   // S1 = 75
        Severity__c = 'Medium',
        Timestamp__c = DateTime.now()
    ));
    
    insert signals;
    System.debug('Successfully inserted ' + signals.size() + ' Flow exhaustion mock signals.');
    
    System.debug('Invoking SentinelPredictionEngine.processSignals()...');
    SentinelPredictionEngine.processSignals(signals);
    
    List<Sentinel_Prediction__c> predictions = [
        SELECT Id, Prediction_Score__c, Status__c, Summary__c, Explanation__c, Operator_Decision__c
        FROM Sentinel_Prediction__c
        WHERE CreatedDate = TODAY
        ORDER BY CreatedDate DESC, Prediction_Score__c DESC
        LIMIT 5
    ];
    
    System.debug('=== SCENARIO C EVALUATION RESULTS ===');
    if (predictions.isEmpty()) {
        System.debug('[WARNING] No prediction card generated for Scenario C. Score likely < 40%. Check weights.');
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
    System.debug('[ERROR] Scenario C Simulation failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    Database.rollback(sp);
    System.debug('Scenario C completed. Database rolled back to preserve sandbox state.');
}
