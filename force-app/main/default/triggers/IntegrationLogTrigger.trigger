trigger IntegrationLogTrigger on Integration_Log__c (after insert, after update) {
    SEOMPAutomationService.createIncidentsForFailedLogs(Trigger.new, Trigger.oldMap);
}
