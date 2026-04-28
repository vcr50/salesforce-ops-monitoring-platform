trigger IntegrationLogTrigger on Integration_Log__c (after insert, after update) {
    SEOMPAutomationService.createIncidentsForFailedLogs(Trigger.new, Trigger.oldMap);
    if (Trigger.isUpdate) {
        SEOMPAutomationService.closeIncidentsForRecoveredLogs(Trigger.new, Trigger.oldMap);
    }
}
