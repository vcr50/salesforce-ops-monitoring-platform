// Scenario A - Low-risk Create Task
// Purpose: Verify that a low-risk incident (score < 40) executes automatically without requiring human approval.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

// Insert low-risk incident
Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'System Incident',
    Risk_Score__c = 15.0, // Low Risk
    Approval_Status__c = 'Not Required',
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'New'
);
insert incident;

System.debug('--- Running Scenario A: Executing low-risk CREATE_TASK ---');
AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');

System.debug('Scenario A Success: ' + result.success);
System.debug('Scenario A Message: ' + result.message);
System.debug('Created Task ID: ' + result.recordId);

// Assertions in debug
Sentinel_Incident__c updated = [SELECT Status__c, Execution_Status__c FROM Sentinel_Incident__c WHERE Id = :incident.Id];
System.debug('Incident Execution Status: ' + updated.Execution_Status__c);
System.debug('Incident Status: ' + updated.Status__c);

if (result.success && updated.Execution_Status__c == 'Executed' && updated.Status__c == 'Action Created') {
    System.debug('=== SCENARIO A PASSED ===');
} else {
    System.debug('=== SCENARIO A FAILED ===');
}
