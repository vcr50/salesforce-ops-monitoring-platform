public with sharing class ZentomReplayController {
    public class ReplayTimelineItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String eventType;
        @AuraEnabled public String decision;
        @AuraEnabled public String traceId;
        @AuraEnabled public String requestPayload;
        @AuraEnabled public String responsePayload;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReplayTimelineItem> getReplayTimeline(Id incidentId) {
        if (incidentId == null) {
            throw new AuraHandledException('Incident Id is required.');
        }

        List<Sentinel_Audit_Log__c> logs = [
            SELECT Id, Event_Type__c, Decision__c, Trace_Id__c, Request_Payload__c,
                Response_Payload__c, CreatedDate, CreatedBy.Name
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incidentId
            ORDER BY CreatedDate ASC, Id ASC
        ];

        List<ReplayTimelineItem> timeline = new List<ReplayTimelineItem>();
        for (Sentinel_Audit_Log__c log : logs) {
            ReplayTimelineItem item = new ReplayTimelineItem();
            item.id = log.Id;
            item.eventType = log.Event_Type__c;
            item.decision = log.Decision__c;
            item.traceId = log.Trace_Id__c;
            item.requestPayload = log.Request_Payload__c;
            item.responsePayload = log.Response_Payload__c;
            item.createdDate = log.CreatedDate;
            item.createdByName = log.CreatedBy.Name;
            timeline.add(item);
        }

        return timeline;
    }
}