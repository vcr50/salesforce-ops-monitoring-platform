// Scenario F - Retry exhaustion after 3 failures
// Purpose: Verify that execution is blocked with RETRY_EXHAUSTED after 3 consecutive failures.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'Retry Exhaustion Check',
    Risk_Score__c = 20.0,
    Approval_Status__c = 'Not Required',
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'New'
);
insert incident;

System.debug('--- Running Scenario F: Simulating 3 consecutive failures ---');
// Run 3 failing attempts
for (Integer i = 0; i < 3; i++) {
    AutoHealExecutionService.executeAction(incident.Id, 'TEST_FORCE_FAILURE');
}

System.debug('--- Running Scenario F: Attempting 4th execution (expecting retry block) ---');
Boolean retryBlocked = false;
try {
    AutoHealExecutionService.executeAction(incident.Id, 'CREATE_TASK');
} catch (AutoHealExecutionService.AutoHealException e) {
    System.debug('Blocked Exception (Expected): ' + e.getMessage());
    if (e.getMessage().contains('Retry Exhaustion')) {
        retryBlocked = true;
    }
}

// Verify audit log for Retry Exhausted block
List<Sentinel_Audit_Log__c> logs = [
    SELECT Event_Type__c, Decision__c
    FROM Sentinel_Audit_Log__c
    WHERE Incident__c = :incident.Id
    AND Decision__c = 'RETRY_EXHAUSTED'
];
Boolean exhaustionLogged = !logs.isEmpty();
System.debug('Exhaustion logged: ' + exhaustionLogged);

if (retryBlocked && exhaustionLogged) {
    System.debug('=== SCENARIO F PASSED ===');
} else {
    System.debug('=== SCENARIO F FAILED ===');
}
