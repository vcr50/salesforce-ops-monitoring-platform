// Scenario B - Medium-risk Create Case with policy approval
// Purpose: Verify that a medium-risk incident (score >= 40) executes successfully when approved by policy.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

// Insert medium-risk approved incident
Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'Integration Timeout',
    Risk_Score__c = 55.0, // Medium Risk
    Approval_Status__c = 'Approved', // Pre-approved by policy/operator
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'Approved'
);
insert incident;

System.debug('--- Running Scenario B: Executing medium-risk CREATE_CASE ---');
AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'CREATE_CASE');

System.debug('Scenario B Success: ' + result.success);
System.debug('Scenario B Message: ' + result.message);
System.debug('Created Case ID: ' + result.recordId);

Sentinel_Incident__c updated = [SELECT Status__c, Execution_Status__c, Created_Case__c FROM Sentinel_Incident__c WHERE Id = :incident.Id];
System.debug('Incident Execution Status: ' + updated.Execution_Status__c);
System.debug('Incident Status: ' + updated.Status__c);

if (result.success && updated.Execution_Status__c == 'Executed' && updated.Created_Case__c == result.recordId) {
    System.debug('=== SCENARIO B PASSED ===');
} else {
    System.debug('=== SCENARIO B FAILED ===');
}
