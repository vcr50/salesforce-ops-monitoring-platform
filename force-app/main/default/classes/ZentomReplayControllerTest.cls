@IsTest
private class ZentomReplayControllerTest {
    @IsTest
    static void getReplayTimeline_returnsAuditLogsInOrder() {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Incident_Type__c = 'FLOW_FAILURE',
            Source__c = 'Salesforce Flow',
            Environment__c = 'production',
            Risk_Score__c = 95,
            Risk_Level__c = 'CRITICAL',
            Status__c = 'Approval Required'
        );
        insert incident;

        insert new List<Sentinel_Audit_Log__c>{
            new Sentinel_Audit_Log__c(
                Incident__c = incident.Id,
                Event_Type__c = 'INCIDENT_RECEIVED',
                Decision__c = 'RECEIVED',
                Trace_Id__c = 'test-1'
            ),
            new Sentinel_Audit_Log__c(
                Incident__c = incident.Id,
                Event_Type__c = 'ZENTOM_POLICY_EVALUATED',
                Decision__c = 'HUMAN_APPROVAL_REQUIRED',
                Trace_Id__c = 'test-2'
            ),
            new Sentinel_Audit_Log__c(
                Incident__c = incident.Id,
                Event_Type__c = 'HUMAN_APPROVED',
                Decision__c = 'APPROVED',
                Trace_Id__c = 'test-3'
            )
        };

        Test.startTest();
        List<ZentomReplayController.ReplayTimelineItem> timeline =
            ZentomReplayController.getReplayTimeline(incident.Id);
        Test.stopTest();

        System.assertEquals(3, timeline.size());
        System.assertEquals('INCIDENT_RECEIVED', timeline[0].eventType);
        System.assertEquals('ZENTOM_POLICY_EVALUATED', timeline[1].eventType);
        System.assertEquals('HUMAN_APPROVED', timeline[2].eventType);
        System.assertEquals('test-3', timeline[2].traceId);
        System.assertNotEquals(null, timeline[0].createdByName);
    }
}