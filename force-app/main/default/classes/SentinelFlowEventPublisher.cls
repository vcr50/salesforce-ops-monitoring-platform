/**
 * SentinelFlowEventPublisher
 * Centrally manages publishing of SentinelFlow_Dashboard_Event__e Platform Events.
 * These events power real-time streaming telemetry in the Command Center.
 *
 * @author TomCodeX Engineering
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class SentinelFlowEventPublisher {

    // Recursion guard to prevent duplicate event publishing for the same event type on an incident
    private static Set<String> publishedIncidentKeys = new Set<String>();

    // @TestVisible counter — incremented every time EventBus.publish() is actually called;
    // lets unit tests verify guard behaviour without relying on DML-count or EventBus test APIs.
    @TestVisible private static Integer publishedEventCount = 0;

    /**
     * Publishes a single telemetry event for an incident context.
     * Enforces deduplication and schema rules.
     *
     * @param eventType The classification of the event (e.g. INCIDENT_CREATED, APPROVAL_REQUIRED)
     * @param incident The incident record containing metrics (can be null for system-wide events)
     * @param source The Apex class or trigger executing this call (e.g. SentinelIncidentTrigger)
     * @param message A short human-readable message summarizing the event
     */
    public static void publish(
        String eventType,
        Sentinel_Incident__c incident,
        String source,
        String message
    ) {
        if (incident != null && incident.Id != null) {
            String guardKey = incident.Id + '_' + eventType;
            if (publishedIncidentKeys.contains(guardKey)) {
                System.debug(LoggingLevel.FINE, '[SentinelFlowEventPublisher] Skip duplicate event: ' + guardKey);
                return;
            }
            publishedIncidentKeys.add(guardKey);
        }

        SentinelFlow_Dashboard_Event__e event = new SentinelFlow_Dashboard_Event__e();
        event.Event_Type__c = eventType;
        event.Event_Source__c = source;
        event.Event_Timestamp__c = System.now();
        event.Message__c = abbreviate(message, 255);

        if (incident != null) {
            event.Incident_Id__c = incident.Id;
            event.Incident_Number__c = incident.Name;
            event.Incident_Type__c = incident.Incident_Type__c;
            event.Risk_Level__c = incident.Risk_Level__c;
            event.Approval_Status__c = incident.Approval_Status__c;
            event.Execution_Status__c = incident.Execution_Status__c;
            event.AI_Reasoning_Status__c = incident.AI_Reasoning_Status__c;
            event.AI_Confidence__c = incident.AI_Confidence__c != null ? Integer.valueOf(incident.AI_Confidence__c) : null;
            event.Environment__c = incident.Environment__c;
        }

        Database.SaveResult result = EventBus.publish(event);
        publishedEventCount++;
        if (!result.isSuccess()) {
            System.debug(LoggingLevel.ERROR, 
                '[SentinelFlowEventPublisher] Failed to publish event: ' + 
                result.getErrors()
            );
        }
    }

    /**
     * Publishes bulk telemetry events for a collection of incidents.
     * Enforces single-DML statement optimization.
     *
     * @param eventType The classification of the events
     * @param incidents The collection of incident records
     * @param source The originating context source
     * @param message A default message summarizing the bulk update
     */
    public static void publishBulk(
        String eventType,
        List<Sentinel_Incident__c> incidents,
        String source,
        String message
    ) {
        if (incidents == null || incidents.isEmpty()) {
            return;
        }

        List<SentinelFlow_Dashboard_Event__e> events = new List<SentinelFlow_Dashboard_Event__e>();

        for (Sentinel_Incident__c inc : incidents) {
            if (inc.Id != null) {
                String guardKey = inc.Id + '_' + eventType;
                if (publishedIncidentKeys.contains(guardKey)) {
                    continue;
                }
                publishedIncidentKeys.add(guardKey);
            }

            SentinelFlow_Dashboard_Event__e event = new SentinelFlow_Dashboard_Event__e();
            event.Event_Type__c = eventType;
            event.Event_Source__c = source;
            event.Event_Timestamp__c = System.now();
            event.Message__c = abbreviate(message, 255);

            event.Incident_Id__c = inc.Id;
            event.Incident_Number__c = inc.Name;
            event.Incident_Type__c = inc.Incident_Type__c;
            event.Risk_Level__c = inc.Risk_Level__c;
            event.Approval_Status__c = inc.Approval_Status__c;
            event.Execution_Status__c = inc.Execution_Status__c;
            event.AI_Reasoning_Status__c = inc.AI_Reasoning_Status__c;
            event.AI_Confidence__c = inc.AI_Confidence__c != null ? Integer.valueOf(inc.AI_Confidence__c) : null;
            event.Environment__c = inc.Environment__c;

            events.add(event);
        }

        if (events.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = EventBus.publish(events);
        publishedEventCount++;
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR, 
                    '[SentinelFlowEventPublisher] Failed to publish bulk event index ' + i + ': ' + 
                    results[i].getErrors()
                );
            }
        }
    }

    /**
     * Publishes a telemetry event that doesn't correspond to an incident context.
     *
     * @param eventType The system event classification (e.g. ERROR_LOGGED)
     * @param source The calling context source
     * @param message Description details
     */
    public static void publishSystemEvent(String eventType, String source, String message) {
        publish(eventType, null, source, message);
    }

    /**
     * Safety helper to truncate long messaging strings.
     */
    private static String abbreviate(String value, Integer maxLen) {
        if (value == null || value.length() <= maxLen) {
            return value;
        }
        return value.substring(0, maxLen);
    }
}
