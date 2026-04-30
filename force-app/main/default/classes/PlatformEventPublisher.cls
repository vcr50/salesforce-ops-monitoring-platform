/**
 * PlatformEventPublisher
 * Publishes Integration_Health_Event__e Platform Events when an
 * Integration_Log__c record transitions to Failed or Warning status.
 * These events drive real-time LWC updates via empApi subscriptions.
 *
 * @author   Tomcodex
 */
public with sharing class PlatformEventPublisher {

    public static void publishIntegrationHealthEvents(
        List<Integration_Log__c> logs
    ) {
        if (logs == null || logs.isEmpty()) { return; }

        List<Integration_Health_Event__e> events = new List<Integration_Health_Event__e>();

        for (Integration_Log__c log : logs) {
            if (log.Status__c == 'Failed' || log.Status__c == 'Warning') {
                Integration_Health_Event__e evt = new Integration_Health_Event__e();
                evt.API_Name__c           = log.API_Name__c;
                evt.Status__c             = log.Status__c;
                evt.Response_Time__c      = log.Response_Time__c != null
                    ? Integer.valueOf(log.Response_Time__c) : null;
                evt.Error_Message__c      = log.Error_Message__c;
                evt.Integration_Log_Id__c = String.valueOf(log.Id);
                events.add(evt);
            }
        }

        if (events.isEmpty()) { return; }

        List<Database.SaveResult> results = EventBus.publish(events);

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'PlatformEventPublisher: Failed to publish event for log '
                    + logs[i].Id + ' — ' + results[i].getErrors());
            }
        }
    }
}
