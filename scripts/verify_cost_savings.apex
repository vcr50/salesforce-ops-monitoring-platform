System.Savepoint sp = Database.setSavepoint();
try {
    System.debug('========================================');
    System.debug('=== SENTINELFLOW COST SAVINGS QA START ===');
    System.debug('========================================');
    
    // Deleting any existing executed incidents in this transaction to ensure QA isolation.
    // These will be fully restored upon rollback.
    List<Sentinel_Incident__c> existing = [
        SELECT Id FROM Sentinel_Incident__c WHERE Execution_Status__c = 'Executed'
    ];
    if (!existing.isEmpty()) {
        System.debug('Deleting ' + existing.size() + ' existing executed incidents temporarily for isolation...');
        delete existing;
    }

    // 1. Setup metadata overrides to ensure predictable baselines
    SystemSettings.setOverride('Engineering_Hourly_Rate', 80.0);
    SystemSettings.setOverride('Manual_Resolution_Hours', 2.0);
    SystemSettings.setOverride('Baseline_MTTR_Minutes', 240.0);
    SystemSettings.setOverride('Cost_Per_Support_Case', 150.0);
    
    Datetime anchor = System.now();
    
    // Incident A: Successful recovery, no Case created (Case Avoided). 30 min duration.
    // We set Executed_At__c in the future by 30 mins to simulate 30 mins elapsed duration from CreatedDate (which will be System.now())
    Sentinel_Incident__c incA = new Sentinel_Incident__c(
        Incident_Type__c = 'FLOW_FAILURE',
        Source__c = 'Salesforce Flow',
        Environment__c = 'production',
        Error_Message__c = 'Flow failed',
        Risk_Score__c = 95,
        Risk_Level__c = 'CRITICAL',
        Status__c = 'Closed',
        AI_Confidence__c = 87,
        Runbook_Key__c = 'RUNBOOK_A',
        AI_Reasoning_Status__c = 'ACTIVE',
        Approval_Status__c = 'Approved',
        Execution_Status__c = 'Executed',
        Created_Case__c = null,
        Executed_At__c = anchor.addMinutes(30)
    );
    
    // Incident B: Successful recovery, Salesforce Case linked (not avoided). 90 min duration.
    Case c = new Case(Subject = 'QA Demo Case', Status = 'New');
    insert c;
    
    Sentinel_Incident__c incB = new Sentinel_Incident__c(
        Incident_Type__c = 'FLOW_FAILURE',
        Source__c = 'Salesforce Flow',
        Environment__c = 'production',
        Error_Message__c = 'Flow failed',
        Risk_Score__c = 45,
        Risk_Level__c = 'HIGH',
        Status__c = 'Closed',
        AI_Confidence__c = 87,
        Runbook_Key__c = 'RUNBOOK_B',
        AI_Reasoning_Status__c = 'ACTIVE',
        Approval_Status__c = 'Approved',
        Execution_Status__c = 'Executed',
        Created_Case__c = c.Id,
        Executed_At__c = anchor.addMinutes(90)
    );
    
    insert new List<Sentinel_Incident__c>{ incA, incB };
    
    // -------------------------------------------------------------
    // Test Scenario A: Engineering Hourly Rate = $80.00
    // -------------------------------------------------------------
    ZentomDashboardController.CostAnalyticsResult resultA = ZentomDashboardController.getCostSavingsAnalytics('ALL');
    
    System.debug('[Scenario A] Hourly Rate: $80.00/hr');
    System.debug('[Scenario A] Successful Recoveries: ' + resultA.successfulRecoveries + ' (Expected: 2)');
    System.debug('[Scenario A] Hours Saved: ' + resultA.hoursSaved + ' hrs (Expected: 4.00)');
    System.debug('[Scenario A] Cases Avoided: ' + resultA.casesAvoided + ' (Expected: 1)');
    System.debug('[Scenario A] Estimated Cost Savings: $' + resultA.estimatedCostSavings + ' (Expected: 470.00)');
    System.debug('[Scenario A] Average Automated MTTR: ' + resultA.automatedMttrMinutes + ' mins (Expected: 60.00)');
    System.debug('[Scenario A] MTTR Improvement: ' + resultA.mttrImprovementPercent + '% (Expected: 75.00)');
    
    // Validation assertions for Scenario A
    System.assertEquals(2, resultA.successfulRecoveries, 'Scenario A: Successful Recoveries calculation mismatch');
    System.assertEquals(4.00, resultA.hoursSaved, 'Scenario A: Hours Saved calculation mismatch');
    System.assertEquals(1, resultA.casesAvoided, 'Scenario A: Cases Avoided calculation mismatch');
    System.assertEquals(470.00, resultA.estimatedCostSavings, 'Scenario A: Estimated Cost Savings mismatch');
    
    // Since CreatedDate takes insertion datetime, there might be a few milliseconds delay between anchor and insertion,
    // so we assert that automatedMttrMinutes is close to 60.00 (within a 0.2 minute threshold).
    System.assert(Math.abs(resultA.automatedMttrMinutes - 60.00) < 0.2, 'Scenario A: Automated MTTR is not close to 60. Actual: ' + resultA.automatedMttrMinutes);
    System.assert(Math.abs(resultA.mttrImprovementPercent - 75.00) < 0.2, 'Scenario A: MTTR Improvement % is not close to 75. Actual: ' + resultA.mttrImprovementPercent);
    
    // -------------------------------------------------------------
    // Test Scenario B: Engineering Hourly Rate Override = $100.00
    // -------------------------------------------------------------
    SystemSettings.setOverride('Engineering_Hourly_Rate', 100.0);
    
    ZentomDashboardController.CostAnalyticsResult resultB = ZentomDashboardController.getCostSavingsAnalytics('ALL');
    
    System.debug('[Scenario B] Hourly Rate Override: $100.00/hr');
    System.debug('[Scenario B] Successful Recoveries: ' + resultB.successfulRecoveries + ' (Expected: 2)');
    System.debug('[Scenario B] Hours Saved: ' + resultB.hoursSaved + ' hrs (Expected: 4.00)');
    System.debug('[Scenario B] Cases Avoided: ' + resultB.casesAvoided + ' (Expected: 1)');
    System.debug('[Scenario B] Estimated Cost Savings (Override): $' + resultB.estimatedCostSavings + ' (Expected: 550.00)');
    
    // Validation assertions for Scenario B
    System.assertEquals(2, resultB.successfulRecoveries, 'Scenario B: Successful Recoveries calculation mismatch');
    System.assertEquals(4.00, resultB.hoursSaved, 'Scenario B: Hours Saved calculation mismatch');
    System.assertEquals(1, resultB.casesAvoided, 'Scenario B: Cases Avoided calculation mismatch');
    System.assertEquals(550.00, resultB.estimatedCostSavings, 'Scenario B: Override Cost Savings calculation mismatch');
    
    System.debug('========================================');
    System.debug('=== QA FORMULA VERIFICATION SUCCESS ===');
    System.debug('========================================');
} catch (Exception ex) {
    System.debug('========================================');
    System.debug('=== QA FORMULA VERIFICATION FAILURE ===');
    System.debug('Exception: ' + ex.getMessage());
    System.debug('Stack Trace: ' + ex.getStackTraceString());
    System.debug('========================================');
    throw ex;
} finally {
    Database.rollback(sp);
    SystemSettings.clearOverrides();
}
