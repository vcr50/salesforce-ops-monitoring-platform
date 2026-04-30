trigger IntegrationLogTrigger on Integration_Log__c (after insert, after update) {
    // 1. Auto-create incidents for newly failed logs
    SEOMPAutomationService.createIncidentsForFailedLogs(Trigger.new, Trigger.oldMap);

    // 2. Close incidents when logs recover
    if (Trigger.isUpdate) {
        SEOMPAutomationService.closeIncidentsForRecoveredLogs(Trigger.new, Trigger.oldMap);
    }

    // 3. Publish platform events for real-time LWC updates
    PlatformEventPublisher.publishIntegrationHealthEvents(Trigger.new);

    // 4. Queue self-healing evaluation for newly failed logs
    //    (Queueable avoids DML-after-callout and keeps trigger lean)
    if (Trigger.isInsert) {
        List<Id> failedLogIds = new List<Id>();
        for (Integration_Log__c log : Trigger.new) {
            if (log.Status__c == 'Failed') {
                failedLogIds.add(log.Id);
            }
        }
        if (!failedLogIds.isEmpty()) {
            System.enqueueJob(new SelfHealQueueable(failedLogIds));
        }
    }
}
