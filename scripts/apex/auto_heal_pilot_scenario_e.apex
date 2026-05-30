// Scenario E - Rollback on failure
// Purpose: Verify that execution failures roll back database mutations atomically and update parent status indicators.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'Rollback Validation',
    Risk_Score__c = 30.0,
    Approval_Status__c = 'Not Required',
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'New'
);
insert incident;

System.debug('--- Running Scenario E: Executing failure-inducing TEST_FORCE_FAILURE ---');
Test.startTest();
AutoHealExecutionService.ExecutionResult result = AutoHealExecutionService.executeAction(incident.Id, 'TEST_FORCE_FAILURE');
Test.stopTest();

System.debug('Scenario E Success: ' + result.success); // Should be false
System.debug('Scenario E Message: ' + result.message);

Sentinel_Incident__c updated = [
    SELECT Execution_Status__c, Status__c, Approval_Status__c, Execution_Result__c
    FROM Sentinel_Incident__c
    WHERE Id = :incident.Id
];
System.debug('Incident Execution Status: ' + updated.Execution_Status__c); // Should be Failed
System.debug('Incident Status: ' + updated.Status__c); // Should be Approval Required
System.debug('Incident Approval Status: ' + updated.Approval_Status__c); // Should be Pending Approval

// Verify audit log exists
List<Sentinel_Audit_Log__c> logs = [
    SELECT Event_Type__c, Decision__c
    FROM Sentinel_Audit_Log__c
    WHERE Incident__c = :incident.Id
    ORDER BY CreatedDate DESC
];
System.debug('Audit Logs Count: ' + logs.size());
Boolean failureLogged = !logs.isEmpty() && logs[0].Event_Type__c == 'AUTO_HEAL_FAILED';

if (!result.success && updated.Execution_Status__c == 'Failed' && 
    updated.Status__c == 'Approval Required' && updated.Approval_Status__c == 'Pending Approval' && failureLogged) {
    System.debug('=== SCENARIO E PASSED ===');
} else {
    System.debug('=== SCENARIO E FAILED ===');
}
