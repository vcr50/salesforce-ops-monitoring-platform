@IsTest
private class SentinelFlowNotificationDispatcherTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('ok');
            return response;
        }
    }

    private class SlackFailsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            if (request.getEndpoint().contains('Slack_Webhook')) {
                response.setStatusCode(500);
                response.setBody('slack unavailable');
            } else {
                response.setStatusCode(200);
                response.setBody('ok');
            }
            return response;
        }
    }

    @IsTest
    static void triggerDispatchesSlackAndTeamsWhenIncidentEntersPendingApproval() {
        createSettings('/services/T000/B000/success', '/webhookb2/success/path');
        Sentinel_Incident__c incident = createIncident('Not Required', 'HIGH');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = true;
        Test.startTest();
        incident.Approval_Status__c = 'Pending Approval';
        update incident;
        Test.stopTest();
        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = false;

        Map<String, Sentinel_Audit_Log__c> logsByEventType = logsByEventType(incident.Id);
        System.assert(logsByEventType.containsKey('SLACK_ALERT_SENT'), 'Slack success should be audited.');
        System.assert(logsByEventType.containsKey('TEAMS_ALERT_SENT'), 'Teams success should be audited.');
        System.assert(!logsByEventType.containsKey('APPROVAL_ALERT_EMAIL_FALLBACK_SENT'), 'Fallback email should not send on full success.');
    }

    @IsTest
    static void failedSlackCalloutAuditsFailureAndSendsFallbackEmail() {
        createSettings('/services/T000/B000/failure', '/webhookb2/success/path');
        Sentinel_Incident__c incident = createPendingFixture('CRITICAL');

        Test.setMock(HttpCalloutMock.class, new SlackFailsMock());
        Test.startTest();
        SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(new List<Id>{ incident.Id });
        Test.stopTest();

        Map<String, Sentinel_Audit_Log__c> logsByEventType = logsByEventType(incident.Id);
        System.assert(logsByEventType.containsKey('SLACK_ALERT_FAILED'), 'Slack failure should be audited.');
        System.assert(logsByEventType.containsKey('TEAMS_ALERT_SENT'), 'Teams should still send if configured.');
        System.assert(logsByEventType.containsKey('APPROVAL_ALERT_EMAIL_FALLBACK_SENT'), 'Email fallback should be audited.');
        System.assertEquals('FALLBACK_EMAIL', logsByEventType.get('SLACK_ALERT_FAILED').Decision__c);
    }

    @IsTest
    static void noConfiguredWebhooksAuditsBothMissingAndSendsFallbackEmail() {
        Sentinel_Incident__c incident = createIncident('Not Required', 'MEDIUM');

        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = true;
        Test.startTest();
        incident.Approval_Status__c = 'Pending Approval';
        update incident;
        Test.stopTest();
        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = false;

        Map<String, Sentinel_Audit_Log__c> logsByEventType = logsByEventType(incident.Id);
        System.assert(logsByEventType.containsKey('SLACK_ALERT_NOT_CONFIGURED'), 'Missing Slack webhook should be audited.');
        System.assert(logsByEventType.containsKey('TEAMS_ALERT_NOT_CONFIGURED'), 'Missing Teams webhook should be audited.');
        System.assert(logsByEventType.containsKey('APPROVAL_ALERT_EMAIL_FALLBACK_SENT'), 'Email fallback should be audited.');
    }

    @IsTest
    static void triggerDoesNotDispatchWhenPendingApprovalValueDoesNotChange() {
        createSettings('/services/T000/B000/success', '/webhookb2/success/path');
        Sentinel_Incident__c incident = createPendingFixture('LOW');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = true;
        Test.startTest();
        incident.Root_Cause__c = 'Updated without status transition';
        update incident;
        Test.stopTest();
        SentinelFlowNotificationDispatcher.enableTriggerDispatchForTests = false;

        List<Sentinel_Audit_Log__c> logs = [
            SELECT Id
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incident.Id
        ];
        System.assertEquals(0, logs.size(), 'Updating a record already pending approval should not dispatch again.');
    }

    @IsTest
    static void tenantWebhookPathsAreUsedWhenOrgDefaultsAreBlank() {
        insert new SentinelFlow_Settings__c();
        insert new Tenant__c(
            Name = 'Notification Tenant',
            Status__c = 'Active',
            Slack_Webhook_Path__c = '/services/T000/B000/tenant',
            Teams_Webhook_Path__c = '/webhookb2/tenant/path'
        );
        Sentinel_Incident__c incident = createPendingFixture('HIGH');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        SentinelFlowNotificationDispatcher.dispatchPendingApprovalAlerts(new List<Id>{ incident.Id });
        Test.stopTest();

        Map<String, Sentinel_Audit_Log__c> logsByEventType = logsByEventType(incident.Id);
        System.assert(logsByEventType.containsKey('SLACK_ALERT_SENT'), 'Tenant Slack path should be used.');
        System.assert(logsByEventType.containsKey('TEAMS_ALERT_SENT'), 'Tenant Teams path should be used.');
    }

    @IsTest
    static void payloadBuildersIncludeApprovalContextAndSafeSalesforceLink() {
        Sentinel_Incident__c incident = createPendingFixture('HIGH');
        String recordUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/' + incident.Id + '/view';

        Map<String, Object> slackPayload = SentinelFlowNotificationDispatcher.buildSlackPayload(incident, recordUrl);
        Map<String, Object> teamsPayload = SentinelFlowNotificationDispatcher.buildTeamsPayload(incident, recordUrl);

        String slackJson = JSON.serialize(slackPayload);
        String teamsJson = JSON.serialize(teamsPayload);
        System.assert(slackJson.contains('Guardian Gate approval required'));
        System.assert(slackJson.contains('Risk score'));
        System.assert(slackJson.contains(recordUrl));
        System.assert(teamsJson.contains('MessageCard'));
        System.assert(teamsJson.contains('Review in Salesforce'));
        System.assert(!slackJson.contains('hooks.slack.com/services'), 'Slack host should stay in the Named Credential.');
        System.assert(!teamsJson.contains('outlook.office.com'), 'Teams host should stay in the Named Credential.');
    }

    private static void createSettings(String slackPath, String teamsPath) {
        insert new SentinelFlow_Settings__c(
            Enable_Alerts__c = true,
            Slack_Webhook_Path__c = slackPath,
            Teams_Webhook_Path__c = teamsPath
        );
    }

    private static Sentinel_Incident__c createIncident(String approvalStatus, String riskLevel) {
        Sentinel_Incident__c incident = new Sentinel_Incident__c(
            Status__c = 'New',
            Approval_Status__c = approvalStatus,
            Risk_Level__c = riskLevel,
            Risk_Score__c = 91,
            Root_Cause__c = 'Policy threshold exceeded',
            Recommended_Action__c = 'Review and approve governed remediation',
            Execution_Action__c = 'Create Salesforce Case for operations review',
            Next_Action__c = 'Awaiting Guardian Gate approval',
            Policy_Decision__c = 'Requires human approval',
            Runbook_Title__c = 'Revenue protection runbook',
            Runbook_Description__c = 'Validate the proposed customer-impacting remediation.'
        );
        insert incident;
        return incident;
    }

    private static Sentinel_Incident__c createPendingFixture(String riskLevel) {
        Sentinel_Incident__c incident = createIncident('Pending Approval', riskLevel);
        return incident;
    }

    private static Map<String, Sentinel_Audit_Log__c> logsByEventType(Id incidentId) {
        Map<String, Sentinel_Audit_Log__c> result = new Map<String, Sentinel_Audit_Log__c>();
        for (Sentinel_Audit_Log__c log : [
            SELECT Event_Type__c, Decision__c
            FROM Sentinel_Audit_Log__c
            WHERE Incident__c = :incidentId
        ]) {
            result.put(log.Event_Type__c, log);
        }
        return result;
    }
}
