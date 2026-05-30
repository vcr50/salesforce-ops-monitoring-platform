// Scenario D - Blocked destructive action
// Purpose: Verify that dangerous/destructive actions (e.g. DELETE_RECORDS) are strictly blocked and never run.

SystemSettings.clearOverrides();
SystemSettings.setOverride('Auto_Heal_Active', 1.0);

Sentinel_Incident__c incident = new Sentinel_Incident__c(
    Incident_Type__c = 'Database Clean',
    Risk_Score__c = 10.0,
    Approval_Status__c = 'Not Required',
    Execution_Status__c = 'Ready for Execution',
    Status__c = 'New'
);
insert incident;

System.debug('--- Running Scenario D: Attempting blocked DELETE_RECORDS action ---');
Boolean deleteBlocked = false;
try {
    AutoHealExecutionService.executeAction(incident.Id, 'DELETE_RECORDS');
} catch (AutoHealExecutionService.AutoHealException e) {
    System.debug('Blocked Exception (Expected): ' + e.getMessage());
    if (e.getMessage().contains('Blocked Action')) {
        deleteBlocked = true;
    }
}

// Verify audit log
List<Sentinel_Audit_Log__c> logs = [
    SELECT Event_Type__c, Decision__c
    FROM Sentinel_Audit_Log__c
    WHERE Incident__c = :incident.Id
];

Boolean logged = !logs.isEmpty() && logs[0].Event_Type__c == 'AUTO_HEAL_BLOCKED' && logs[0].Decision__c == 'BLOCKED_ACTION';
System.debug('Audit log created: ' + logged);

if (deleteBlocked && logged) {
    System.debug('=== SCENARIO D PASSED ===');
} else {
    System.debug('=== SCENARIO D FAILED ===');
}
