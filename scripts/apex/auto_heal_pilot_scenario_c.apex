// Scenario C - High-risk action requiring Guardian Gate
// Purpose: Verify that a high-risk incident (score >= 40) is blocked if unapproved, and runs successfully once approved.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

// Insert high-risk unapproved incident
Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'Security Access',
    Risk_Score__c = 85.0, // High Risk
    Approval_Status__c = 'Pending Approval', // Awaiting operator review
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'New'
);
insert incident;

System.debug('--- Running Scenario C: Attempting unapproved execution ---');
Boolean blockSuccess = false;
try {
    AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');
} catch (AutoHealExecutionService.AutoHealException e) {
    System.debug('Blocked Exception (Expected): ' + e.getMessage());
    if (e.getMessage().contains('require human approval')) {
        blockSuccess = true;
    }
}

System.debug('--- Running Scenario C: Granting approval and executing ---');
incident.Approval_Status__c = 'Approved';
update incident;

Test.startTest();
AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');
Test.stopTest();

System.debug('Scenario C Success: ' + result.success);
System.debug('Scenario C Message: ' + result.message);

Sentinel_Incident__c updated = [SELECT Status__c, Execution_Status__c FROM Sentinel_Incident__c WHERE Id = :incident.Id];
System.debug('Incident Execution Status: ' + updated.Execution_Status__c);

if (blockSuccess && result.success && updated.Execution_Status__c == 'Executed') {
    System.debug('=== SCENARIO C PASSED ===');
} else {
    System.debug('=== SCENARIO C FAILED ===');
}
